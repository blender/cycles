/* SPDX-FileCopyrightText: 2022 NVIDIA Corporation
 * SPDX-FileCopyrightText: 2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#include "hydra/mesh.h"
#include "hydra/geometry.inl"
#include "hydra/util.h"
#include "scene/mesh.h"

#include <pxr/base/gf/vec2f.h>
#include <pxr/imaging/hd/geomSubsetSchema.h>
#include <pxr/imaging/hd/legacyDisplayStyleSchema.h>
#include <pxr/imaging/hd/materialBindingSchema.h>
#include <pxr/imaging/hd/materialBindingsSchema.h>
#include <pxr/imaging/hd/meshSchema.h>
#include <pxr/imaging/hd/meshTopologySchema.h>
#include <pxr/imaging/hd/sceneIndex.h>
#include <pxr/imaging/hd/subdivisionTagsSchema.h>

HDCYCLES_NAMESPACE_OPEN_SCOPE

namespace {

void RemoveUVTangents(AttributeSet &attributes, const ustring &name)
{
  for (const char *suffix :
       {".tangent", ".tangent_sign", ".undisplaced_tangent", ".undisplaced_tangent_sign"})
  {
    attributes.remove(ustring(name.string() + suffix));
  }
}

VtValue ComputeFaceVaryingUVPrimvar(VtValue value,
                                    const HdInterpolation interpolation,
                                    const HdMeshTopology &topology)
{
  if (!value.IsHolding<VtVec2fArray>()) {
    return VtValue();
  }

  const VtVec2fArray &uvs = value.UncheckedGet<VtVec2fArray>();
  const VtIntArray &counts = topology.GetFaceVertexCounts();
  const VtIntArray &indices = topology.GetFaceVertexIndices();
  size_t numCorners = 0;
  for (const int count : counts) {
    if (count < 0 || size_t(count) > indices.size() - numCorners) {
      return VtValue();
    }
    numCorners += count;
  }
  if (numCorners != indices.size() || uvs.empty()) {
    return VtValue();
  }

  if (interpolation == HdInterpolationFaceVarying) {
    if (uvs.size() < numCorners) {
      return VtValue();
    }
    /* Ignore values past the last corner, as triangulation does. */
    return uvs.size() == numCorners ?
               value :
               VtValue(VtVec2fArray(uvs.cbegin(), uvs.cbegin() + numCorners));
  }

  if (interpolation == HdInterpolationUniform && uvs.size() < counts.size()) {
    return VtValue();
  }

  VtVec2fArray cornerUVs;
  cornerUVs.reserve(numCorners);
  size_t corner = 0;
  for (size_t face = 0; face < counts.size(); ++face) {
    for (int i = 0; i < counts[face]; ++i, ++corner) {
      size_t index = 0;
      if (interpolation == HdInterpolationUniform) {
        index = face;
      }
      else if (interpolation == HdInterpolationVertex || interpolation == HdInterpolationVarying) {
        if (indices[corner] < 0 || size_t(indices[corner]) >= uvs.size()) {
          return VtValue();
        }
        index = indices[corner];
      }
      cornerUVs.push_back(uvs[index]);
    }
  }
  return VtValue(std::move(cornerUVs));
}

template<typename T>
VtValue ComputeTriangulatedUniformPrimvar(VtValue value, const VtIntArray &primitiveParams)
{
  T output;
  output.reserve(primitiveParams.size());
  const T &input = value.Get<T>();

  for (size_t i = 0; i < primitiveParams.size(); ++i) {
    const int faceIndex = HdMeshUtil::DecodeFaceIndexFromCoarseFaceParam(primitiveParams[i]);

    output.push_back(input[faceIndex]);
  }

  return VtValue(output);
}

VtValue ComputeTriangulatedUniformPrimvar(VtValue value,
                                          const HdType valueType,
                                          const VtIntArray &primitiveParams)
{
  switch (valueType) {
    case HdTypeFloat:
      return ComputeTriangulatedUniformPrimvar<VtFloatArray>(value, primitiveParams);
    case HdTypeFloatVec2:
      return ComputeTriangulatedUniformPrimvar<VtVec2fArray>(value, primitiveParams);
    case HdTypeFloatVec3:
      return ComputeTriangulatedUniformPrimvar<VtVec3fArray>(value, primitiveParams);
    case HdTypeFloatVec4:
      return ComputeTriangulatedUniformPrimvar<VtVec4fArray>(value, primitiveParams);
    default:
      TF_RUNTIME_ERROR("Unsupported attribute type %d", static_cast<int>(valueType));
      return VtValue();
  }
}

VtValue ComputeTriangulatedFaceVaryingPrimvar(VtValue value,
                                              const HdType valueType,
                                              HdMeshUtil &meshUtil)
{
  if (meshUtil.ComputeTriangulatedFaceVaryingPrimvar(
          HdGetValueData(value), value.GetArraySize(), valueType, &value)
#if PXR_VERSION >= 2511
      != HdMeshComputationResult::Error
#endif
  )
  {
    return value;
  }

  return VtValue();
}

}  // namespace

Transform convert_transform(const GfMatrix4d &matrix)
{
  return make_transform(matrix[0][0],
                        matrix[1][0],
                        matrix[2][0],
                        matrix[3][0],
                        matrix[0][1],
                        matrix[1][1],
                        matrix[2][1],
                        matrix[3][1],
                        matrix[0][2],
                        matrix[1][2],
                        matrix[2][2],
                        matrix[3][2]);
}

HdCyclesMesh::HdCyclesMesh(const SdfPath &rprimId)
    : HdCyclesGeometry(rprimId), _util(&_topology, rprimId)
{
}

HdCyclesMesh::~HdCyclesMesh() = default;

HdDirtyBits HdCyclesMesh::GetInitialDirtyBitsMask() const
{
  HdDirtyBits bits = HdCyclesGeometry::GetInitialDirtyBitsMask();
  bits |= HdChangeTracker::DirtyPoints | HdChangeTracker::DirtyNormals |
          HdChangeTracker::DirtyPrimvar | HdChangeTracker::DirtyTopology |
          HdChangeTracker::DirtyDisplayStyle | HdChangeTracker::DirtySubdivTags;
  return bits;
}

HdDirtyBits HdCyclesMesh::_PropagateDirtyBits(HdDirtyBits bits) const
{
  if (bits & (HdChangeTracker::DirtyMaterialId)) {
    // Update used shaders from geometry subsets if any exist in the topology
    bits |= HdChangeTracker::DirtyTopology;
  }

  if (bits & (HdChangeTracker::DirtyTopology | HdChangeTracker::DirtyDisplayStyle |
              HdChangeTracker::DirtySubdivTags))
  {
    // Do full topology update when display style or subdivision changes
    bits |= HdChangeTracker::DirtyTopology | HdChangeTracker::DirtyDisplayStyle |
            HdChangeTracker::DirtySubdivTags;
  }

  if (bits & (HdChangeTracker::DirtyTopology)) {
    // Changing topology clears the geometry, so need to populate everything again
    bits |= HdChangeTracker::DirtyPoints | HdChangeTracker::DirtyNormals |
            HdChangeTracker::DirtyPrimvar;
  }

  return bits;
}

void HdCyclesMesh::Populate(HdSceneDelegate *sceneDelegate, HdDirtyBits dirtyBits, bool &rebuild)
{
  /* Rebuild subdivision and displacement from the authored geometry when primvars change.
   * Decided here, under the scene lock, because displacement depends on shader state. */
  if ((dirtyBits & HdChangeTracker::DirtyPrimvar) &&
      (_geom->get_subdivision_type() != Mesh::SUBDIVISION_NONE || _geom->has_true_displacement()))
  {
    dirtyBits |= HdChangeTracker::DirtyTopology | HdChangeTracker::DirtyPoints |
                 HdChangeTracker::DirtyNormals;
  }

  if (HdChangeTracker::IsTopologyDirty(dirtyBits, GetId())) {
    PopulateTopology(sceneDelegate);
  }

  if (dirtyBits & HdChangeTracker::DirtyPoints) {
    PopulatePoints(sceneDelegate);
  }

  // Must happen after topology update, so that normals attribute size can be calculated
  if (dirtyBits & HdChangeTracker::DirtyNormals) {
    PopulateNormals(sceneDelegate);
  }

  // Must happen after topology update, so that appropriate attribute set can be selected
  if (dirtyBits & HdChangeTracker::DirtyPrimvar) {
    PopulatePrimvars(sceneDelegate);
  }

  rebuild = (_geom->triangles_is_modified()) || (_geom->subd_start_corner_is_modified()) ||
            (_geom->subd_num_corners_is_modified()) || (_geom->subd_shader_is_modified()) ||
            (_geom->subd_smooth_is_modified()) || (_geom->subd_ptex_offset_is_modified()) ||
            (_geom->subd_face_corners_is_modified());
}

void HdCyclesMesh::PopulatePoints(HdSceneDelegate *sceneDelegate)
{
  const HdSceneIndexPrim prim = GetPrim(sceneDelegate, GetId());
  const HdPrimvarsSchema primvars = HdPrimvarsSchema::GetFromParent(prim.dataSource);
  const VtValue value = ReadPrimvar(primvars, HdTokens->points);

  if (!value.IsHolding<VtVec3fArray>()) {
    TF_WARN("Invalid points data for %s", GetId().GetText());
    return;
  }

  const auto &points = value.UncheckedGet<VtVec3fArray>();

  TF_VERIFY(points.size() >= static_cast<size_t>(_topology.GetNumPoints()));

  const bool subdivision = _geom->get_subdivision_type() != Mesh::SUBDIVISION_NONE;
  AttributeSet &attributes = (subdivision) ? _geom->subd_attributes : _geom->attributes;
  Attribute *attr_P = attributes.add(ATTR_STD_POSITION);
  packed_float3 *verts = attr_P->data_for_write<packed_float3>();

  std::copy_n(
      reinterpret_cast<const packed_float3 *>(points.data()), _topology.GetNumPoints(), verts);
  _geom->tag_position_modified();
}

void HdCyclesMesh::PopulateNormals(HdSceneDelegate *sceneDelegate)
{
  _geom->attributes.remove(ATTR_STD_VERTEX_NORMAL);

  // Authored normals should only exist on triangle meshes
  if (_geom->get_subdivision_type() != Mesh::SUBDIVISION_NONE) {
    return;
  }

  const HdSceneIndexPrim prim = GetPrim(sceneDelegate, GetId());
  const HdPrimvarsSchema primvars = HdPrimvarsSchema::GetFromParent(prim.dataSource);
  const HdInterpolation interpolation = ReadPrimvarInterpolation(primvars, HdTokens->normals);
  if (interpolation == HdInterpolationCount) {
    return;  // Ignore missing normals
  }
  const VtValue value = ReadPrimvar(primvars, HdTokens->normals);

  if (!value.IsHolding<VtVec3fArray>()) {
    TF_WARN("Invalid normals data for %s", GetId().GetText());
    return;
  }

  const auto &normals = value.UncheckedGet<VtVec3fArray>();

  if (interpolation == HdInterpolationConstant) {
    TF_VERIFY(normals.size() == 1);

    const GfVec3f constantNormal = normals[0];

    packed_normal *const N =
        _geom->attributes.add(ATTR_STD_VERTEX_NORMAL)->data_for_write<packed_normal>();
    for (size_t i = 0; i < _geom->num_verts(); ++i) {
      N[i] = packed_normal(make_float3(constantNormal[0], constantNormal[1], constantNormal[2]));
    }
  }
  else if (interpolation == HdInterpolationUniform) {
    TF_VERIFY(normals.size() == static_cast<size_t>(_topology.GetNumFaces()));
    /* Nothing to do, face normals are computed on demand in the kernel. */
  }
  else if (interpolation == HdInterpolationVertex || interpolation == HdInterpolationVarying) {
    TF_VERIFY(normals.size() == static_cast<size_t>(_topology.GetNumPoints()) &&
              static_cast<size_t>(_topology.GetNumPoints()) == _geom->num_verts());

    packed_normal *const N =
        _geom->attributes.add(ATTR_STD_VERTEX_NORMAL)->data_for_write<packed_normal>();
    for (size_t i = 0; i < _geom->num_verts(); ++i) {
      N[i] = packed_normal(make_float3(normals[i][0], normals[i][1], normals[i][2]));
    }
  }
  else if (interpolation == HdInterpolationFaceVarying) {
    TF_VERIFY(normals.size() == static_cast<size_t>(_topology.GetNumFaceVaryings()));

    // TODO: Cycles has no per-corner normals, so ignore until supported.
#if 0
    if (!_util.ComputeTriangulatedFaceVaryingPrimvar(
            normals.data(), normals.size(), HdTypeFloatVec3, &value))
    {
      return;
    }

    const auto &normalsTriangulated = value.UncheckedGet<VtVec3fArray>();
#endif
  }
}

void HdCyclesMesh::PopulatePrimvars(HdSceneDelegate *sceneDelegate)
{
  Scene *const scene = (Scene *)_geom->get_owner();

  const bool subdivision = _geom->get_subdivision_type() != Mesh::SUBDIVISION_NONE;
  AttributeSet &attributes = subdivision ? _geom->subd_attributes : _geom->attributes;

  /* Remove UVs before reading them again. */
  while (const Attribute *previous = attributes.find(ATTR_STD_UV)) {
    RemoveUVTangents(_geom->attributes, previous->name);
    attributes.remove(previous->name);
  }

  const HdSceneIndexPrim prim = GetPrim(sceneDelegate, GetId());
  const HdPrimvarsSchema primvars = HdPrimvarsSchema::GetFromParent(prim.dataSource);

  const std::pair<HdInterpolation, AttributeElement> interpolations[] = {
      std::make_pair(HdInterpolationFaceVarying, ATTR_ELEMENT_CORNER),
      std::make_pair(HdInterpolationUniform, ATTR_ELEMENT_FACE),
      std::make_pair(HdInterpolationVertex, ATTR_ELEMENT_VERTEX),
      std::make_pair(HdInterpolationVarying, ATTR_ELEMENT_VERTEX),
      std::make_pair(HdInterpolationConstant, ATTR_ELEMENT_OBJECT),
  };

  for (const auto &interpolation : interpolations) {
    for (const TfToken &primvarName : PrimvarNamesAtInterpolation(primvars, interpolation.first)) {
      // Skip special primvars that are handled separately
      if (primvarName == HdTokens->points || primvarName == HdTokens->normals) {
        continue;
      }

      VtValue value = ReadPrimvar(primvars, primvarName);
      if (value.IsEmpty()) {
        continue;
      }

      const TfToken role = ReadPrimvarRole(primvars, primvarName);
      const ustring name(primvarName.GetString());
      const HdType valueType = HdGetValueTupleType(value).type;

      /* Remove previous attribute to recreate, in case type, role or interpolation changed. */
      if (Attribute *previous = attributes.find(name)) {
        if (previous->std == ATTR_STD_NONE || previous->std == ATTR_STD_UV ||
            previous->std == ATTR_STD_VERTEX_COLOR)
        {
          RemoveUVTangents(_geom->attributes, name);
          attributes.remove(name);
        }
      }

      AttributeStandard std = ATTR_STD_NONE;
      if (role == HdPrimvarRoleTokens->textureCoordinate && valueType == HdTypeFloatVec2) {
        std = ATTR_STD_UV;
      }
      else if (interpolation.first == HdInterpolationVertex) {
        if (primvarName == HdTokens->displayColor || role == HdPrimvarRoleTokens->color) {
          std = ATTR_STD_VERTEX_COLOR;
        }
        else if (primvarName == HdTokens->normals) {
          std = ATTR_STD_VERTEX_NORMAL;
        }
      }
      else if (primvarName == HdTokens->displayColor &&
               interpolation.first == HdInterpolationConstant)
      {
        if (value.IsHolding<VtVec3fArray>() && value.GetArraySize() == 1) {
          SetDisplayColor(value.UncheckedGet<VtVec3fArray>()[0]);
        }
      }

      // Skip attributes that are not needed
      if ((std != ATTR_STD_NONE && _geom->need_attribute(scene, std)) ||
          _geom->need_attribute(scene, name))
      {
        /* Constant texture coordinates may be scalars; attribute storage uses arrays. */
        if (role == HdPrimvarRoleTokens->textureCoordinate &&
            interpolation.first == HdInterpolationConstant)
        {
          if (value.IsHolding<GfVec2f>()) {
            value = VtVec2fArray{value.UncheckedGet<GfVec2f>()};
          }
          else if (value.IsHolding<GfVec3f>()) {
            value = VtVec3fArray{value.UncheckedGet<GfVec3f>()};
          }
          else if (value.IsHolding<GfVec4f>()) {
            value = VtVec4fArray{value.UncheckedGet<GfVec4f>()};
          }
        }

        HdInterpolation primvarInterpolation = interpolation.first;
        AttributeElement element = interpolation.second;

        /* Expand UVs to corners for Cycles tangent generation. Do this before
         * triangulation so the face-varying conversion handles polygons. */
        if (std == ATTR_STD_UV) {
          value = ComputeFaceVaryingUVPrimvar(value, primvarInterpolation, _topology);
          if (value.IsEmpty()) {
            TF_WARN("Invalid UV data for %s: %s", GetId().GetText(), primvarName.GetText());
            continue;
          }
          primvarInterpolation = HdInterpolationFaceVarying;
          element = ATTR_ELEMENT_CORNER;
        }

        if (!subdivision) {
          // Adjust attributes for polygons that were triangulated
          if (primvarInterpolation == HdInterpolationUniform) {
            value = ComputeTriangulatedUniformPrimvar(value, valueType, _primitiveParams);
            if (value.IsEmpty()) {
              continue;
            }
          }
          else if (primvarInterpolation == HdInterpolationFaceVarying) {
            value = ComputeTriangulatedFaceVaryingPrimvar(value, valueType, _util);
            if (value.IsEmpty() || !TF_VERIFY(value.GetArraySize() == _geom->num_triangles() * 3))
            {
              continue;
            }
          }
        }

        ApplyPrimvars(attributes, name, value, element, std);
        if (subdivision && std == ATTR_STD_UV && interpolation.first != HdInterpolationFaceVarying)
        {
          /* Other domains used linear subdivision before corner conversion. */
          attributes.find(name)->flags |= ATTR_SUBDIVIDE_LINEAR_FVAR;
        }
      }
    }
  }

  /* Tangents are derived from UVs and may include named or fallback maps. */
  for (const AttributeStandard std : {ATTR_STD_UV_TANGENT,
                                      ATTR_STD_UV_TANGENT_SIGN,
                                      ATTR_STD_UV_TANGENT_UNDISPLACED,
                                      ATTR_STD_UV_TANGENT_SIGN_UNDISPLACED})
  {
    while (_geom->attributes.find(std)) {
      _geom->attributes.remove(std);
    }
  }

  if (!subdivision && !_geom->is_modified()) {
    /* An attribute-only edit does not need a BVH update. */
    _geom->add_vertex_normals();
    _geom->update_tangents(scene, true);
    _geom->update_tangents(scene, false);
    _geom->tag_update(scene, false);
  }
}

void HdCyclesMesh::PopulateTopology(HdSceneDelegate *sceneDelegate)
{
  // Clear geometry before populating it again with updated topology
  _geom->clear(true);

  const HdSceneIndexPrim prim = GetPrim(sceneDelegate, GetId());
  const HdLegacyDisplayStyleSchema displayStyleSchema = HdLegacyDisplayStyleSchema::GetFromParent(
      prim.dataSource);

  int refineLevel = 0;
  if (auto ds = displayStyleSchema.GetRefineLevel()) {
    refineLevel = ds->GetTypedValue(0.0f);
  }
  bool flatShadingEnabled = false;
  if (auto ds = displayStyleSchema.GetFlatShadingEnabled()) {
    flatShadingEnabled = ds->GetTypedValue(0.0f);
  }

  const HdMeshSchema meshSchema = HdMeshSchema::GetFromParent(prim.dataSource);
  const HdMeshTopologySchema topoSchema = meshSchema.GetTopology();

  TfToken scheme = PxOsdOpenSubdivTokens->none;
  if (auto ds = meshSchema.GetSubdivisionScheme()) {
    scheme = ds->GetTypedValue(0.0f);
  }
  TfToken orientation = HdTokens->rightHanded;
  if (auto ds = topoSchema.GetOrientation()) {
    orientation = ds->GetTypedValue(0.0f);
  }
  VtIntArray faceVertexCounts;
  if (auto ds = topoSchema.GetFaceVertexCounts()) {
    faceVertexCounts = ds->GetTypedValue(0.0f);
  }
  VtIntArray faceVertexIndices;
  if (auto ds = topoSchema.GetFaceVertexIndices()) {
    faceVertexIndices = ds->GetTypedValue(0.0f);
  }
  VtIntArray holeIndices;
  if (auto ds = topoSchema.GetHoleIndices()) {
    holeIndices = ds->GetTypedValue(0.0f);
  }

  /* Use refinement only for supported subdivision meshes, so triangle indices
   * and face-varying primvars agree about which holes to omit. */
  const bool useSubdivision = refineLevel > 0 && (scheme == PxOsdOpenSubdivTokens->bilinear ||
                                                  scheme == PxOsdOpenSubdivTokens->catmullClark);
  _topology = HdMeshTopology(scheme,
                             orientation,
                             faceVertexCounts,
                             faceVertexIndices,
                             holeIndices,
                             useSubdivision ? refineLevel : 0);

  /* Geom subsets are published as child prims of the mesh in the scene index. */
  HdGeomSubsets geomSubsetsList;
  if (HdSceneIndexBaseRefPtr si = sceneDelegate->GetRenderIndex().GetTerminalSceneIndex()) {
    for (const SdfPath &childPath : si->GetChildPrimPaths(GetId())) {
      const HdSceneIndexPrim childPrim = si->GetPrim(childPath);
      if (childPrim.primType != HdPrimTypeTokens->geomSubset) {
        continue;
      }
      const HdGeomSubsetSchema subsetSchema = HdGeomSubsetSchema::GetFromParent(
          childPrim.dataSource);
      /* Only face subsets supported here, not point or curve subsets. */
      if (auto typeDs = subsetSchema.GetType()) {
        if (typeDs->GetTypedValue(0.0f) != HdGeomSubsetSchemaTokens->typeFaceSet) {
          continue;
        }
      }
      HdGeomSubset subset;
      subset.type = HdGeomSubset::TypeFaceSet;
      if (auto ds = subsetSchema.GetIndices()) {
        subset.indices = ds->GetTypedValue(0.0f);
      }
      if (auto pathDs = HdMaterialBindingsSchema::GetFromParent(childPrim.dataSource)
                            .GetMaterialBinding()
                            .GetPath())
      {
        subset.materialId = pathDs->GetTypedValue(0.0f);
      }
      geomSubsetsList.push_back(subset);
    }
  }
  _topology.SetGeomSubsets(geomSubsetsList);

  const TfToken subdivScheme = _topology.GetScheme();
  if (subdivScheme == PxOsdOpenSubdivTokens->bilinear && _topology.GetRefineLevel() > 0) {
    _geom->set_subdivision_type(Mesh::SUBDIVISION_LINEAR);
  }
  else if (subdivScheme == PxOsdOpenSubdivTokens->catmullClark && _topology.GetRefineLevel() > 0) {
    _geom->set_subdivision_type(Mesh::SUBDIVISION_CATMULL_CLARK);
  }
  else {
    _geom->set_subdivision_type(Mesh::SUBDIVISION_NONE);
  }

  const bool smooth = !flatShadingEnabled;
  const bool subdivision = _geom->get_subdivision_type() != Mesh::SUBDIVISION_NONE;

  // Initialize lookup table from polygon face to material shader index
  VtIntArray faceShaders(_topology.GetNumFaces(), 0);

  const HdGeomSubsets &geomSubsets = _topology.GetGeomSubsets();
  if (!geomSubsets.empty()) {
    array<Node *> usedShaders = std::move(_geom->get_used_shaders());
    // Remove any previous materials except for the material assigned to the prim
    usedShaders.resize(1);

    std::unordered_map<SdfPath, int, SdfPath::Hash> materials;

    for (const HdGeomSubset &geomSubset : geomSubsets) {
      TF_VERIFY(geomSubset.type == HdGeomSubset::TypeFaceSet);

      int shader = 0;
      const auto it = materials.find(geomSubset.materialId);
      if (it != materials.end()) {
        shader = it->second;
      }
      else {
        const auto *const material = static_cast<const HdCyclesMaterial *>(
            sceneDelegate->GetRenderIndex().GetSprim(HdPrimTypeTokens->material,
                                                     geomSubset.materialId));

        if (material && material->GetCyclesShader()) {
          shader = static_cast<int>(usedShaders.size());
          usedShaders.push_back_slow(material->GetCyclesShader());

          materials.emplace(geomSubset.materialId, shader);
        }
      }

      for (const int face : geomSubset.indices) {
        faceShaders[face] = shader;
      }
    }

    _geom->set_used_shaders(usedShaders);
  }

  const VtIntArray vertIndx = _topology.GetFaceVertexIndices();
  const VtIntArray vertCounts = _topology.GetFaceVertexCounts();

  if (!subdivision) {
    VtVec3iArray triangles;
    _util.ComputeTriangleIndices(&triangles, &_primitiveParams);

    _geom->resize_mesh(_topology.GetNumPoints(), triangles.size());

    int *geom_indices = _geom->get_triangles().data();
    for (size_t i = 0; i < _primitiveParams.size(); ++i) {
      const GfVec3i triangle = triangles[i];
      geom_indices[i * 3 + 0] = triangle[0];
      geom_indices[i * 3 + 1] = triangle[1];
      geom_indices[i * 3 + 2] = triangle[2];
    }

    int *shader = _geom->get_shader().data();
    for (size_t i = 0; i < _primitiveParams.size(); ++i) {
      const int faceIndex = HdMeshUtil::DecodeFaceIndexFromCoarseFaceParam(_primitiveParams[i]);
      shader[i] = faceShaders[faceIndex];
    }

    std::ranges::fill(_geom->get_smooth(), smooth);

    _geom->tag_triangles_modified();
    _geom->tag_shader_modified();
    _geom->tag_smooth_modified();
  }
  else {
    const HdSubdivisionTagsSchema subdivSchema = HdSubdivisionTagsSchema::GetFromParent(
        prim.dataSource);
    PxOsdSubdivTags subdivTags;
    if (auto ds = subdivSchema.GetInterpolateBoundary()) {
      subdivTags.SetVertexInterpolationRule(ds->GetTypedValue(0.0f));
    }
    if (auto ds = subdivSchema.GetFaceVaryingLinearInterpolation()) {
      subdivTags.SetFaceVaryingInterpolationRule(ds->GetTypedValue(0.0f));
    }
    if (auto ds = subdivSchema.GetTriangleSubdivisionRule()) {
      subdivTags.SetTriangleSubdivision(ds->GetTypedValue(0.0f));
    }
    if (auto ds = subdivSchema.GetCornerIndices()) {
      subdivTags.SetCornerIndices(ds->GetTypedValue(0.0f));
    }
    if (auto ds = subdivSchema.GetCornerSharpnesses()) {
      subdivTags.SetCornerWeights(ds->GetTypedValue(0.0f));
    }
    if (auto ds = subdivSchema.GetCreaseIndices()) {
      subdivTags.SetCreaseIndices(ds->GetTypedValue(0.0f));
    }
    if (auto ds = subdivSchema.GetCreaseLengths()) {
      subdivTags.SetCreaseLengths(ds->GetTypedValue(0.0f));
    }
    if (auto ds = subdivSchema.GetCreaseSharpnesses()) {
      subdivTags.SetCreaseWeights(ds->GetTypedValue(0.0f));
    }
    _topology.SetSubdivTags(subdivTags);

    size_t numCorners = 0;
    for (const int vertCount : vertCounts) {
      numCorners += vertCount;
    }

    _geom->resize_subd_faces(_topology.GetNumFaces(), numCorners);
    _geom->resize_mesh(_topology.GetNumPoints(), 0);
    Attribute *subd_attr_P = _geom->subd_attributes.add(ATTR_STD_POSITION);
    subd_attr_P->resize(_topology.GetNumPoints());

    std::copy_n(vertIndx.data(), vertIndx.size(), _geom->get_subd_face_corners().data());

    int *subd_start_corner = _geom->get_subd_start_corner().data();
    int *subd_num_corners = _geom->get_subd_num_corners().data();
    int *subd_ptex_offset = _geom->get_subd_ptex_offset().data();

    // TODO: Handle hole indices
    int ptex_offset = 0;
    size_t faceIndex = 0;
    size_t indexOffset = 0;
    for (const int vertCount : vertCounts) {
      subd_start_corner[faceIndex] = indexOffset;
      subd_num_corners[faceIndex] = vertCount;
      subd_ptex_offset[faceIndex] = ptex_offset;
      const int num_ptex = (vertCount == 4) ? 1 : vertCount;
      ptex_offset += num_ptex;

      faceIndex++;
      indexOffset += vertCount;
    }

    std::copy_n(faceShaders.data(), faceShaders.size(), _geom->get_subd_shader().data());
    std::ranges::fill(_geom->get_subd_smooth(), smooth);

    _geom->tag_subd_face_corners_modified();
    _geom->tag_subd_start_corner_modified();
    _geom->tag_subd_num_corners_modified();
    _geom->tag_subd_shader_modified();
    _geom->tag_subd_smooth_modified();
    _geom->tag_subd_ptex_offset_modified();

    const VtIntArray creaseLengths = subdivTags.GetCreaseLengths();
    if (!creaseLengths.empty()) {
      size_t numCreases = 0;
      for (const int creaseLength : creaseLengths) {
        numCreases += creaseLength - 1;
      }

      _geom->reserve_subd_creases(numCreases);

      const VtIntArray creaseIndices = subdivTags.GetCreaseIndices();
      const VtFloatArray creaseWeights = subdivTags.GetCreaseWeights();

      indexOffset = 0;
      size_t creaseLengthOffset = 0;
      size_t createWeightOffset = 0;
      for (const int creaseLength : creaseLengths) {
        for (int j = 0; j < creaseLength - 1; ++j, ++createWeightOffset) {
          const int v0 = creaseIndices[indexOffset + j];
          const int v1 = creaseIndices[indexOffset + j + 1];

          const float weight = creaseWeights.size() == creaseLengths.size() ?
                                   creaseWeights[creaseLengthOffset] :
                                   creaseWeights[createWeightOffset];

          _geom->add_edge_crease(v0, v1, weight);
        }

        indexOffset += creaseLength;
        creaseLengthOffset++;
      }

      const VtIntArray cornerIndices = subdivTags.GetCornerIndices();
      const VtFloatArray cornerWeights = subdivTags.GetCornerWeights();

      for (size_t i = 0; i < cornerIndices.size(); ++i) {
        _geom->add_vertex_crease(cornerIndices[i], cornerWeights[i]);
      }
    }

    _geom->set_subd_dicing_rate(1.0f);
    _geom->set_subd_max_level(_topology.GetRefineLevel());
    if (!_instances.empty()) {
      _geom->set_subd_objecttoworld(_instances[0]->get_tfm());
    }
  }
}

void HdCyclesMesh::Finalize(PXR_NS::HdRenderParam *renderParam)
{
  _topology = HdMeshTopology();
  _primitiveParams.clear();

  HdCyclesGeometry<PXR_NS::HdMesh, Mesh>::Finalize(renderParam);
}

HDCYCLES_NAMESPACE_CLOSE_SCOPE
