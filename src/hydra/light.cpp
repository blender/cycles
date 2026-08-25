/* SPDX-FileCopyrightText: 2022 NVIDIA Corporation
 * SPDX-FileCopyrightText: 2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#include "hydra/light.h"
#include "hydra/session.h"
#include "hydra/util.h"
#include "kernel/types.h"
#include "scene/light.h"
#include "scene/object.h"
#include "scene/scene.h"
#include "scene/shader.h"
#include "scene/shader_graph.h"
#include "scene/shader_nodes.h"
#include "util/hash.h"
#include "util/ies.h"
#include "util/path.h"
#include "util/transform.h"

#include <pxr/imaging/hd/lightSchema.h>
#include <pxr/imaging/hd/sceneDelegate.h>
#include <pxr/imaging/hd/visibilitySchema.h>
#include <pxr/imaging/hd/xformSchema.h>
#include <pxr/usd/sdf/assetPath.h>
#include <pxr/usd/usdLux/tokens.h>

HDCYCLES_NAMESPACE_OPEN_SCOPE

extern Transform convert_transform(const GfMatrix4d &matrix);

// clang-format off
TF_DEFINE_PRIVATE_TOKENS(_tokens,
    (visibleInPrimaryRay)
    (falloff)
);
// clang-format on

HdCyclesLight::HdCyclesLight(const SdfPath &sprimId, const TfToken &lightType)
    : HdLight(sprimId), _lightType(lightType)
{
}

HdCyclesLight::~HdCyclesLight() = default;

HdDirtyBits HdCyclesLight::GetInitialDirtyBitsMask() const
{
  return DirtyBits::DirtyTransform | DirtyBits::DirtyParams;
}

void HdCyclesLight::Sync(HdSceneDelegate *sceneDelegate,
                         HdRenderParam *renderParam,
                         HdDirtyBits *dirtyBits)
{
  if (*dirtyBits == DirtyBits::Clean) {
    return;
  }

  Initialize(renderParam);

  const SceneLock lock(renderParam);

  const SdfPath &id = GetId();
  const HdSceneIndexPrim prim = GetPrim(sceneDelegate, id);
  const HdContainerDataSourceHandle &primDs = prim.dataSource;
  const HdContainerDataSourceHandle lightDs = HdLightSchema::GetFromParent(primDs).GetContainer();

  if (*dirtyBits & DirtyBits::DirtyTransform) {
    GfMatrix4d xform(1.0);
    if (auto matrixDs = HdXformSchema::GetFromParent(primDs).GetMatrix()) {
      xform = matrixDs->GetTypedValue(0.0f);
    }

    _object->set_tfm(convert_transform(xform));
  }

  if (*dirtyBits & (DirtyBits::DirtyParams | DirtyBits::DirtyTransform)) {
    float3 strength = make_float3(1.0f, 1.0f, 1.0f);

    {
      const GfVec3f color = GetTypedValue<GfVec3f>(
          lightDs, HdLightTokens->color, GfVec3f(1.0f, 1.0f, 1.0f));
      strength = make_float3(color[0], color[1], color[2]);
    }

    strength *= exp2(GetTypedValue<float>(lightDs, HdLightTokens->exposure, 0.0f));
    strength *= GetTypedValue<float>(lightDs, HdLightTokens->intensity, 1.0f);

    if (_lightType != HdPrimTypeTokens->domeLight && _lightType != HdPrimTypeTokens->distantLight)
    {
      /* Convert from intensity to radiant flux. */
      strength *= M_PI_F;
    }

    /* We dont use Blender's normalization, but calculate our own values to match USDLux.
    Normalization code is taken from:
    https://openusd.org/dev/user_guides/schemas/usdLux/LightAPI.html#lightapi-inputs-normalize */
    bool normalize = GetTypedValue<bool>(lightDs, HdLightTokens->normalize, false);

    float area = 1.0f;

    _light->set_normalize(false);

    if (auto ds = GetTypedDataSource<bool>(lightDs, _tokens->visibleInPrimaryRay)) {
      if (ds->GetTypedValue(0.0f)) {
        _object->set_visibility(_object->get_visibility() | PATH_RAY_VISIBILITY_CAMERA);
      }
      else {
        _object->set_visibility(_object->get_visibility() & ~PATH_RAY_VISIBILITY_CAMERA);
      }
    }

    if (auto ds = GetTypedDataSource<bool>(lightDs, HdLightTokens->shadowEnable)) {
      _light->set_cast_shadow(ds->GetTypedValue(0.0f));
    }

    if (_lightType == HdPrimTypeTokens->distantLight) {
      const float angleDeg = GetTypedValue<float>(lightDs, HdLightTokens->angle, 0.53f);
      const float angleRad = GfDegreesToRadians(angleDeg);
      static_cast<SunLight *>(_light)->set_angle(angleRad);

      const float max_theta = clamp(angleRad / 2.0f, 0.0f, M_PI_F);

      if (max_theta == 0.0f) {
        area = 1.0f;
      }
      else if (max_theta <= M_PI_2_F) {
        area = powf(sinf(max_theta), 2.0f) * M_PI_F;
      }
      else {
        area = (2.0f - powf(sinf(max_theta), 2.0f)) * M_PI_F;
      }
    }
    else if (_lightType == HdPrimTypeTokens->diskLight ||
             _lightType == HdPrimTypeTokens->rectLight)
    {
      AreaLight *area_light = static_cast<AreaLight *>(_light);

      area_light->set_spread(M_PI_F);

      if (_lightType == HdPrimTypeTokens->diskLight) {
        const float radius = GetTypedValue<float>(lightDs, HdLightTokens->radius, 0.5f);
        const float size = radius * 2.0f;
        area_light->set_sizeu(size);
        area_light->set_sizev(size);
      }
      else {
        const float width = GetTypedValue<float>(lightDs, HdLightTokens->width, 1.0f);
        const float height = GetTypedValue<float>(lightDs, HdLightTokens->height, 1.0f);
        area_light->set_sizeu(width);
        area_light->set_sizev(height);
      }

      area = area_light->area(_object->get_tfm());
    }
    else if (_lightType == HdPrimTypeTokens->sphereLight) {
      SpotLight *spot_light = static_cast<SpotLight *>(_light);
      const bool treatAsPoint = GetTypedValue<bool>(lightDs, UsdLuxTokens->treatAsPoint, false);
      const float radius = GetTypedValue<float>(lightDs, HdLightTokens->radius, 0.5f);

      const Transform &tfm = _object->get_tfm();
      const float scale_x = len(transform_get_column(&tfm, 0));
      const float scale_y = len(transform_get_column(&tfm, 1));
      const float scale_z = len(transform_get_column(&tfm, 2));
      const float avg_scale = (scale_x + scale_y + scale_z) / 3.0f;

      if (treatAsPoint || radius == 0.0f) {
        spot_light->set_radius(0.0f);
        area = 1.0f;
      }
      else {
        const float world_radius = radius * avg_scale;
        spot_light->set_radius(world_radius);
        area = 4.0f * M_PI_F * powf(world_radius, 2.0f);
      }

      spot_light->set_smooth(0.0f);
      _light->set_light_type(LIGHT_POINT);
    }

    if (normalize) {
      if (area != 0) {
        strength /= area;
      }
    }

    bool visible = true;
    if (auto ds = HdVisibilitySchema::GetFromParent(primDs).GetVisibility()) {
      visible = ds->GetTypedValue(0.0f);
    }
    /* Disable invisible lights by zeroing the strength
    So 'LightManager::test_enabled_lights' updates the enabled flag correctly */
    if (!visible) {
      strength = zero_float3();
    }

    _light->set_strength(strength);
    _light->set_is_enabled(visible);

    PopulateShaderGraph(lightDs, renderParam);
  }
  /* Need to update shader graph when transform changes in case transform was baked into it */
  else if (_object->tfm_is_modified() && (_lightType == HdPrimTypeTokens->domeLight ||
                                          _light->get_shader()->has_surface_spatial_varying))
  {
    PopulateShaderGraph(lightDs, renderParam);
  }

  if (_light->is_modified()) {
    _light->tag_update(lock.scene);
  }

  *dirtyBits = DirtyBits::Clean;
}

static void BuildIESNodes(ShaderGraph *graph,
                          IESLightNode *iesNode,
                          float angleScale,
                          ShaderNode *outputNode)
{
  /* Transform Incoming to local light space and normalize */
  GeometryNode *geomNode = graph->create_node<GeometryNode>();
  VectorTransformNode *xformNode = graph->create_node<VectorTransformNode>();
  xformNode->set_transform_type(NODE_VECTOR_TRANSFORM_TYPE_VECTOR);
  xformNode->set_convert_from(NODE_VECTOR_TRANSFORM_CONVERT_SPACE_WORLD);
  xformNode->set_convert_to(NODE_VECTOR_TRANSFORM_CONVERT_SPACE_OBJECT);
  graph->connect(geomNode->output("Incoming"), xformNode->input("Vector"));

  VectorMathNode *normNode = graph->create_node<VectorMathNode>();
  normNode->set_math_type(NODE_VECTOR_MATH_NORMALIZE);
  graph->connect(xformNode->output("Vector"), normNode->input("Vector1"));

  SeparateXYZNode *sepNode = graph->create_node<SeparateXYZNode>();
  graph->connect(normNode->output("Vector"), sepNode->input("Vector"));

  ShaderOutput *outZ = sepNode->output("Z");
  ShaderOutput *iesFacOutput = iesNode->output("Fac");

  if (angleScale != 0.0f && angleScale != 1.0f) {
    /* In local light space, emission axis is -Z -> cos(theta) = -Z */
    MathNode *negZNode = graph->create_node<MathNode>();
    negZNode->set_math_type(NODE_MATH_MULTIPLY);
    negZNode->set_value2(-1.0f);
    graph->connect(sepNode->output("Z"), negZNode->input("Value1"));

    ClampNode *clampCosNode = graph->create_node<ClampNode>();
    clampCosNode->set_min(-1.0f);
    clampCosNode->set_max(1.0f);
    graph->connect(negZNode->output("Value"), clampCosNode->input("Value"));

    MathNode *acosNode = graph->create_node<MathNode>();
    acosNode->set_math_type(NODE_MATH_ARCCOSINE);
    graph->connect(clampCosNode->output("Result"), acosNode->input("Value1"));

    ShaderOutput *scaledThetaOutput = nullptr;
    if (angleScale > 0.0f) {
      MathNode *scaleThetaNode = graph->create_node<MathNode>();
      scaleThetaNode->set_math_type(NODE_MATH_MULTIPLY);
      scaleThetaNode->set_value2(1.0f / angleScale);
      graph->connect(acosNode->output("Value"), scaleThetaNode->input("Value1"));
      scaledThetaOutput = scaleThetaNode->output("Value");
    }
    else {
      MathNode *scaleThetaNode = graph->create_node<MathNode>();
      scaleThetaNode->set_math_type(NODE_MATH_MULTIPLY);
      scaleThetaNode->set_value2(1.0f / -angleScale);
      graph->connect(acosNode->output("Value"), scaleThetaNode->input("Value1"));

      MathNode *addThetaNode = graph->create_node<MathNode>();
      addThetaNode->set_math_type(NODE_MATH_ADD);
      addThetaNode->set_value2(M_PI_F * (1.0f - 1.0f / -angleScale));
      graph->connect(scaleThetaNode->output("Value"), addThetaNode->input("Value1"));
      scaledThetaOutput = addThetaNode->output("Value");
    }

    ClampNode *clampThetaNode = graph->create_node<ClampNode>();
    clampThetaNode->set_min(0.0f);
    clampThetaNode->set_max(M_PI_F - 0.005f);
    graph->connect(scaledThetaOutput, clampThetaNode->input("Value"));

    /* New Z = -cos(theta_ies) */
    MathNode *cosNode = graph->create_node<MathNode>();
    cosNode->set_math_type(NODE_MATH_COSINE);
    graph->connect(clampThetaNode->output("Result"), cosNode->input("Value1"));

    MathNode *newZNode = graph->create_node<MathNode>();
    newZNode->set_math_type(NODE_MATH_MULTIPLY);
    newZNode->set_value2(-1.0f);
    graph->connect(cosNode->output("Value"), newZNode->input("Value1"));
    outZ = newZNode->output("Value");

    /* New XY magnitude = sin(theta_ies) */
    MathNode *sinNode = graph->create_node<MathNode>();
    sinNode->set_math_type(NODE_MATH_SINE);
    graph->connect(clampThetaNode->output("Result"), sinNode->input("Value1"));

    CombineXYZNode *xyVecNode = graph->create_node<CombineXYZNode>();
    xyVecNode->set_z(0.0f);
    graph->connect(sepNode->output("X"), xyVecNode->input("X"));
    graph->connect(sepNode->output("Y"), xyVecNode->input("Y"));

    VectorMathNode *normXYNode = graph->create_node<VectorMathNode>();
    normXYNode->set_math_type(NODE_VECTOR_MATH_NORMALIZE);
    graph->connect(xyVecNode->output("Vector"), normXYNode->input("Vector1"));

    VectorMathNode *scaleXYNode = graph->create_node<VectorMathNode>();
    scaleXYNode->set_math_type(NODE_VECTOR_MATH_SCALE);
    graph->connect(normXYNode->output("Vector"), scaleXYNode->input("Vector1"));
    graph->connect(sinNode->output("Value"), scaleXYNode->input("Scale"));

    SeparateXYZNode *scaledSepNode = graph->create_node<SeparateXYZNode>();
    graph->connect(scaleXYNode->output("Vector"), scaledSepNode->input("Vector"));
    sepNode = scaledSepNode;

    if (angleScale < 0.0f) {
      /* For negative angleScale, mask out directions where scaled theta < 0 */
      MathNode *gteZeroNode = graph->create_node<MathNode>();
      gteZeroNode->set_math_type(NODE_MATH_GREATER_THAN);
      gteZeroNode->set_value2(-1e-4f);
      graph->connect(scaledThetaOutput, gteZeroNode->input("Value1"));

      MathNode *maskedFacNode = graph->create_node<MathNode>();
      maskedFacNode->set_math_type(NODE_MATH_MULTIPLY);
      graph->connect(iesNode->output("Fac"), maskedFacNode->input("Value1"));
      graph->connect(gteZeroNode->output("Value"), maskedFacNode->input("Value2"));
      iesFacOutput = maskedFacNode->output("Value");
    }
  }

  /* Align USD Lux photometric coordinate frame with Cycles IES node (Cycles: X = Y_usd, Y = X_usd,
   * Z = Z_usd) */
  CombineXYZNode *finalVecNode = graph->create_node<CombineXYZNode>();
  graph->connect(sepNode->output("Y"), finalVecNode->input("X"));
  graph->connect(sepNode->output("X"), finalVecNode->input("Y"));
  graph->connect(outZ, finalVecNode->input("Z"));

  graph->connect(finalVecNode->output("Vector"), iesNode->input("Vector"));

  ShaderInput *const strengthInput = outputNode->input("Strength");
  if (strengthInput) {
    if (strengthInput->link) {
      ShaderOutput *const previousOutput = strengthInput->link;
      graph->disconnect(strengthInput);

      MathNode *mulNode = graph->create_node<MathNode>();
      mulNode->set_math_type(NODE_MATH_MULTIPLY);
      graph->connect(previousOutput, mulNode->input("Value1"));
      graph->connect(iesFacOutput, mulNode->input("Value2"));
      graph->connect(mulNode->output("Value"), strengthInput);
    }
    else {
      graph->connect(iesFacOutput, strengthInput);
    }
  }
}

static void BuildConeShapingNodes(ShaderGraph *graph,
                                  float coneAngleDeg,
                                  float coneSoftness,
                                  ShaderNode *outputNode)
{
  const float clampedHalfAngleDeg = clamp(coneAngleDeg, 0.001f, 180.0f);
  const float thetaCutoff = GfDegreesToRadians(clampedHalfAngleDeg);
  const float clampedSoftness = clamp(coneSoftness, 0.0f, 1.0f);
  const float thetaSmoothStart = (1.0f - clampedSoftness) * thetaCutoff;

  GeometryNode *geomNode = graph->create_node<GeometryNode>();

  /* Transform Incoming from world space to object (light) space */
  VectorTransformNode *xformNode = graph->create_node<VectorTransformNode>();
  xformNode->set_transform_type(NODE_VECTOR_TRANSFORM_TYPE_VECTOR);
  xformNode->set_convert_from(NODE_VECTOR_TRANSFORM_CONVERT_SPACE_WORLD);
  xformNode->set_convert_to(NODE_VECTOR_TRANSFORM_CONVERT_SPACE_OBJECT);
  graph->connect(geomNode->output("Incoming"), xformNode->input("Vector"));

  VectorMathNode *normNode = graph->create_node<VectorMathNode>();
  normNode->set_math_type(NODE_VECTOR_MATH_NORMALIZE);
  graph->connect(xformNode->output("Vector"), normNode->input("Vector1"));

  SeparateXYZNode *sepNode = graph->create_node<SeparateXYZNode>();
  graph->connect(normNode->output("Vector"), sepNode->input("Vector"));

  /* In local light space, emission axis is -Z. cos(theta) = -Z */
  MathNode *negZNode = graph->create_node<MathNode>();
  negZNode->set_math_type(NODE_MATH_MULTIPLY);
  negZNode->set_value2(-1.0f);
  graph->connect(sepNode->output("Z"), negZNode->input("Value1"));

  ClampNode *clampCosNode = graph->create_node<ClampNode>();
  clampCosNode->set_min(-1.0f);
  clampCosNode->set_max(1.0f);
  graph->connect(negZNode->output("Value"), clampCosNode->input("Value"));

  MathNode *acosNode = graph->create_node<MathNode>();
  acosNode->set_math_type(NODE_MATH_ARCCOSINE);
  graph->connect(clampCosNode->output("Result"), acosNode->input("Value1"));

  ShaderOutput *coneFacOutput = nullptr;

  if (clampedSoftness > 0.0f && thetaSmoothStart < thetaCutoff) {
    MapRangeNode *mapRangeNode = graph->create_node<MapRangeNode>();
    mapRangeNode->set_range_type(NODE_MAP_RANGE_SMOOTHSTEP);
    mapRangeNode->set_from_min(thetaSmoothStart);
    mapRangeNode->set_from_max(thetaCutoff);
    mapRangeNode->set_to_min(1.0f);
    mapRangeNode->set_to_max(0.0f);
    mapRangeNode->set_clamp(true);
    graph->connect(acosNode->output("Value"), mapRangeNode->input("Value"));
    coneFacOutput = mapRangeNode->output("Result");
  }
  else {
    MathNode *compNode = graph->create_node<MathNode>();
    compNode->set_math_type(NODE_MATH_GREATER_THAN);
    compNode->set_value1(thetaCutoff + 1e-5f);
    graph->connect(acosNode->output("Value"), compNode->input("Value2"));
    coneFacOutput = compNode->output("Value");
  }

  ShaderInput *const strengthInput = outputNode->input("Strength");
  if (strengthInput) {
    if (strengthInput->link) {
      ShaderOutput *const previousOutput = strengthInput->link;
      graph->disconnect(strengthInput);

      MathNode *mulNode = graph->create_node<MathNode>();
      mulNode->set_math_type(NODE_MATH_MULTIPLY);
      graph->connect(previousOutput, mulNode->input("Value1"));
      graph->connect(coneFacOutput, mulNode->input("Value2"));
      graph->connect(mulNode->output("Value"), strengthInput);
    }
    else {
      graph->connect(coneFacOutput, strengthInput);
    }
  }
}

static void BuildFocusShapingNodes(ShaderGraph *graph,
                                   float focusShaping,
                                   float3 focusTint,
                                   ShaderNode *outputNode)
{
  GeometryNode *geometryNode = graph->create_node<GeometryNode>();

  /* Transform Incoming from world space to object (light) space */
  VectorTransformNode *xformNode = graph->create_node<VectorTransformNode>();
  xformNode->set_transform_type(NODE_VECTOR_TRANSFORM_TYPE_VECTOR);
  xformNode->set_convert_from(NODE_VECTOR_TRANSFORM_CONVERT_SPACE_WORLD);
  xformNode->set_convert_to(NODE_VECTOR_TRANSFORM_CONVERT_SPACE_OBJECT);
  graph->connect(geometryNode->output("Incoming"), xformNode->input("Vector"));

  /* Normalize to ensure unit length regardless of object scale. */
  VectorMathNode *normNode = graph->create_node<VectorMathNode>();
  normNode->set_math_type(NODE_VECTOR_MATH_NORMALIZE);
  graph->connect(xformNode->output("Vector"), normNode->input("Vector1"));

  SeparateXYZNode *sepNode = graph->create_node<SeparateXYZNode>();
  graph->connect(normNode->output("Vector"), sepNode->input("Vector"));

  /* UsdLux defines focus with the absolute value of the dot product, so sphere and cylinder
   * lights also emit behind the light. */
  MathNode *absoluteNode = graph->create_node<MathNode>();
  absoluteNode->set_math_type(NODE_MATH_ABSOLUTE);
  graph->connect(sepNode->output("Z"), absoluteNode->input("Value1"));

  ClampNode *clampCosNode = graph->create_node<ClampNode>();
  clampCosNode->set_min(0.0f);
  clampCosNode->set_max(1.0f);
  graph->connect(absoluteNode->output("Value"), clampCosNode->input("Value"));

  MathNode *powerNode = graph->create_node<MathNode>();
  powerNode->set_math_type(NODE_MATH_POWER);
  powerNode->set_value2(focusShaping);
  graph->connect(clampCosNode->output("Result"), powerNode->input("Value1"));

  ClampNode *clampFacNode = graph->create_node<ClampNode>();
  clampFacNode->set_min(0.0f);
  clampFacNode->set_max(1.0f);
  graph->connect(powerNode->output("Value"), clampFacNode->input("Value"));

  MixNode *mixNode = graph->create_node<MixNode>();
  mixNode->set_mix_type(NODE_MIX_BLEND);
  mixNode->set_use_clamp(true);

  graph->connect(clampFacNode->output("Result"), mixNode->input("Fac"));

  /* focusColor = lerp(focusFactor, focusTint, [1, 1, 1])
  In MixNode: result = (1 - Fac) * Color1 + Fac * Color2 */
  mixNode->set_color1(focusTint);
  mixNode->set_color2(make_float3(1.0f, 1.0f, 1.0f));

  /* Inject focusColor before outputNode's Color input (multiply by existing color) */
  ShaderInput *const targetColorInput = outputNode->input("Color");
  if (targetColorInput) {
    if (targetColorInput->link) {
      ShaderOutput *const previousOutput = targetColorInput->link;
      graph->disconnect(targetColorInput);

      VectorMathNode *mulNode = graph->create_node<VectorMathNode>();
      mulNode->set_math_type(NODE_VECTOR_MATH_MULTIPLY);
      graph->connect(previousOutput, mulNode->input("Vector1"));
      graph->connect(mixNode->output("Color"), mulNode->input("Vector2"));
      graph->connect(mulNode->output("Vector"), targetColorInput);
    }
    else {
      graph->connect(mixNode->output("Color"), targetColorInput);
    }
  }
}

void HdCyclesLight::PopulateShaderGraph(const HdContainerDataSourceHandle &lightContainer,
                                        HdRenderParam *renderParam)
{
  unique_ptr<ShaderGraph> graph = make_unique<ShaderGraph>();
  ShaderNode *outputNode = nullptr;

  if (_lightType == HdPrimTypeTokens->domeLight) {
    BackgroundNode *bgNode = graph->create_node<BackgroundNode>();
    /* Bake strength into shader graph, since only the shader is used for background lights */
    bgNode->set_color(_light->get_strength());

    graph->connect(bgNode->output("Background"), graph->output()->input("Surface"));

    outputNode = bgNode;
  }
  else {
    EmissionNode *emissionNode = graph->create_node<EmissionNode>();
    emissionNode->set_color(one_float3());
    emissionNode->set_strength(1.0f);

    graph->connect(emissionNode->output("Emission"), graph->output()->input("Surface"));

    if (lightContainer) {
      if (auto ds = HdStringDataSource::Cast(lightContainer->Get(_tokens->falloff))) {
        const std::string strVal = ds->GetTypedValue(0.0f);
        if (strVal == "Constant" || strVal == "Linear" || strVal == "Quadratic") {
          LightFalloffNode *lfoNode = graph->create_node<LightFalloffNode>();
          lfoNode->set_strength(1.0f);
          graph->connect(lfoNode->output(strVal.c_str()), emissionNode->input("Strength"));
        }
      }
    }

    outputNode = emissionNode;
  }

  bool hasSpatialVarying = false;
  bool hasColorTemperature = false;

  if (lightContainer) {
    const bool enableColorTemperature = GetTypedValue<bool>(
        lightContainer, HdLightTokens->enableColorTemperature, false);

    if (enableColorTemperature) {
      if (auto ds = HdFloatDataSource::Cast(lightContainer->Get(HdLightTokens->colorTemperature)))
      {
        BlackbodyNode *blackbodyNode = graph->create_node<BlackbodyNode>();
        blackbodyNode->set_temperature(ds->GetTypedValue(0.0f));

        if (_lightType == HdPrimTypeTokens->domeLight) {
          VectorMathNode *mathNode = graph->create_node<VectorMathNode>();
          mathNode->set_math_type(NODE_VECTOR_MATH_MULTIPLY);
          mathNode->set_vector2(_light->get_strength());

          graph->connect(blackbodyNode->output("Color"), mathNode->input("Vector1"));
          graph->connect(mathNode->output("Vector"), outputNode->input("Color"));
        }
        else {
          graph->connect(blackbodyNode->output("Color"), outputNode->input("Color"));
        }

        hasColorTemperature = true;
      }
    }

    if (auto ds = HdAssetPathDataSource::Cast(lightContainer->Get(HdLightTokens->shapingIesFile)))
    {
      const SdfAssetPath assetPath = ds->GetTypedValue(0.0f);
      std::string filename = assetPath.GetResolvedPath();
      if (filename.empty()) {
        filename = assetPath.GetAssetPath();
      }

      if (!filename.empty()) {
        IESLightNode *iesNode = graph->create_node<IESLightNode>();
        iesNode->set_filename(ustring(filename));

        bool iesNormalize = false;
        if (auto ds = GetTypedDataSource<bool>(lightContainer, HdLightTokens->shapingIesNormalize))
        {
          iesNormalize = ds->GetTypedValue(false);
        }

        float iesStrength = 1.0f;
        bool didNormalize = false;

        /* USDLux requires the intensity of IES lights to be normalized
         * We calculate an iesStrength factor to use to normalize the IES light intensity
         * (total_power) 1 (normalized intensity) = 4pi (surface area of a normalized sphere) /
         * iesStrength */
        if (iesNormalize) {
          string content;
          if (path_read_text(filename, content)) {
            IESFile ies;
            if (ies.load(content)) {
              const float total_power = ies.integrate();
              if (total_power > 0.0f) {
                iesStrength = (4.0f * M_PI_F) / total_power;
                didNormalize = true;
              }
            }
          }
        }

        /* When normalization not requested or failed, invert Cycles' internal factor to use raw
         * photometric candelas */
        if (!didNormalize) {
          iesStrength = 1.0f / 0.0706650768394f;
        }

        iesNode->set_strength(iesStrength);

        float angleScale = 0.0f;
        if (auto ds = GetTypedDataSource<float>(lightContainer,
                                                HdLightTokens->shapingIesAngleScale))
        {
          angleScale = ds->GetTypedValue(0.0f);
        }

        BuildIESNodes(graph.get(), iesNode, angleScale, outputNode);

        hasSpatialVarying = true;
      }
    }

    if (auto ds = HdAssetPathDataSource::Cast(lightContainer->Get(HdLightTokens->textureFile))) {
      const SdfAssetPath assetPath = ds->GetTypedValue(0.0f);
      std::string filename = assetPath.GetResolvedPath();
      if (filename.empty()) {
        filename = assetPath.GetAssetPath();
      }

      if (!filename.empty()) {
        ImageSlotTextureNode *textureNode = nullptr;
        if (_lightType == HdPrimTypeTokens->domeLight) {
          Transform tfm = _object->get_tfm();
          transform_set_column(&tfm, 3, zero_float3());  // Remove translation

          /* For DomeLight_1, UsdImaging resolves poleAxis ("scene", "Y", "Z") and the stage's
           * upAxis into a GfMatrix4d under HdLightTokens->domeOffset (+90 deg x rotation when
           * Z-up) */
          if (auto offsetDs = HdMatrixDataSource::Cast(
                  lightContainer->Get(HdLightTokens->domeOffset)))
          {
            const GfMatrix4d domeOffset = offsetDs->GetTypedValue(0.0f);

            tfm = tfm * convert_transform(domeOffset);
          }

          /* Rotate from Blender's Z-up to USD's default Y-up (cancels with domeOffset when Z-up)
           */
          tfm = tfm * transform_rotate(-M_PI_2_F, make_float3(1.0f, 0.0f, 0.0f));

          /* We then spin around Blender's Z-up to align with USDLux */
          tfm = tfm * transform_rotate(-M_PI_2_F, make_float3(0.0f, 0.0f, 1.0f));

          TextureCoordinateNode *coordNode = graph->create_node<TextureCoordinateNode>();
          coordNode->set_ob_tfm(tfm);
          coordNode->set_use_transform(true);

          textureNode = graph->create_node<EnvironmentTextureNode>();
          static_cast<EnvironmentTextureNode *>(textureNode)->set_filename(ustring(filename));

          graph->connect(coordNode->output("Object"), textureNode->input("Vector"));

          hasSpatialVarying = true;
        }
        else {
          GeometryNode *coordNode = graph->create_node<GeometryNode>();

          MappingNode *mappingNode = graph->create_node<MappingNode>();

          /* in Blender, UV coordinates are different between lights and surfaces, while USD
           * assumes they are the same. We flip on the x for emissive area lights with textures to
           * treat it as a surface.
           */
          mappingNode->set_scale(make_float3(-1.0f, 1.0f, 1.0f));

          graph->connect(coordNode->output("Parametric"), mappingNode->input("Vector"));

          textureNode = graph->create_node<ImageTextureNode>();
          static_cast<ImageTextureNode *>(textureNode)->set_filename(ustring(filename));
          graph->connect(mappingNode->output("Vector"), textureNode->input("Vector"));
        }

        if (hasColorTemperature) {
          VectorMathNode *mathNode = graph->create_node<VectorMathNode>();
          mathNode->set_math_type(NODE_VECTOR_MATH_MULTIPLY);

          graph->connect(textureNode->output("Color"), mathNode->input("Vector1"));
          ShaderInput *const outputNodeInput = outputNode->input("Color");
          graph->connect(outputNodeInput->link, mathNode->input("Vector2"));
          graph->disconnect(outputNodeInput);
          graph->connect(mathNode->output("Vector"), outputNodeInput);
        }
        else if (_lightType == HdPrimTypeTokens->domeLight) {
          VectorMathNode *mathNode = graph->create_node<VectorMathNode>();
          mathNode->set_math_type(NODE_VECTOR_MATH_MULTIPLY);
          mathNode->set_vector2(_light->get_strength());

          graph->connect(textureNode->output("Color"), mathNode->input("Vector1"));
          graph->connect(mathNode->output("Vector"), outputNode->input("Color"));
        }
        else {
          graph->connect(textureNode->output("Color"), outputNode->input("Color"));
        }
      }
    }

    if (auto ds = GetTypedDataSource<float>(lightContainer, HdLightTokens->shapingFocus)) {
      const float focusShaping = ds->GetTypedValue(0.0f);

      if (focusShaping > 0.0f && _lightType != HdPrimTypeTokens->domeLight) {
        /* Fetch shaping:focusTint (default is black) */
        float3 focusTint = zero_float3();
        if (auto tintDs = GetTypedDataSource<GfVec3f>(lightContainer,
                                                      HdLightTokens->shapingFocusTint))
        {
          const GfVec3f tint = tintDs->GetTypedValue(0.0f);
          focusTint = make_float3(tint[0], tint[1], tint[2]);
        }

        BuildFocusShapingNodes(graph.get(), focusShaping, focusTint, outputNode);

        hasSpatialVarying = true;
      }
    }

    const float coneAngle = GetTypedValue<float>(
        lightContainer, HdLightTokens->shapingConeAngle, 90.0f);
    const float coneSoftness = clamp(
        GetTypedValue<float>(lightContainer, HdLightTokens->shapingConeSoftness, 0.0f),
        0.0f,
        1.0f);

    const bool hasConeShaping = (coneAngle < 90.0f || coneSoftness > 0.0f);
    if (hasConeShaping && _lightType != HdPrimTypeTokens->domeLight &&
        _lightType != HdPrimTypeTokens->distantLight)
    {
      BuildConeShapingNodes(graph.get(), coneAngle, coneSoftness, outputNode);
      hasSpatialVarying = true;
    }
  }

  Shader *const shader = _light->get_shader();
  shader->set_graph(std::move(graph));
  shader->tag_update((Scene *)_light->get_owner());

  shader->has_surface_spatial_varying = hasSpatialVarying;
}

void HdCyclesLight::Finalize(HdRenderParam *renderParam)
{
  if (!_light) {
    return;
  }

  const SceneLock lock(renderParam);
  const bool keep_nodes = static_cast<const HdCyclesSession *>(renderParam)->keep_nodes;

  if (!keep_nodes) {
    HdCyclesSession *const session = static_cast<HdCyclesSession *>(renderParam);
    session->DeleteNode(_object);
    session->DeleteNode(_light);
  }

  _light = nullptr;
  _object = nullptr;
}

void HdCyclesLight::Initialize(HdRenderParam *renderParam)
{
  if (_light) {
    return;
  }

  const SceneLock lock(renderParam);

  _object = lock.scene->create_node<Object>();
  _object->name = GetId().GetString();

  if (_lightType == HdPrimTypeTokens->domeLight) {
    _light = lock.scene->create_node<BackgroundLight>();
  }
  else if (_lightType == HdPrimTypeTokens->distantLight) {
    _light = lock.scene->create_node<SunLight>();
  }
  else if (_lightType == HdPrimTypeTokens->diskLight) {
    _light = lock.scene->create_node<AreaLight>();
    static_cast<AreaLight *>(_light)->set_ellipse(true);
  }
  else if (_lightType == HdPrimTypeTokens->rectLight) {
    _light = lock.scene->create_node<AreaLight>();
    static_cast<AreaLight *>(_light)->set_ellipse(false);
  }
  else if (_lightType == HdPrimTypeTokens->sphereLight) {
    /* We can't know in advance if this is spot light or point light, so we set to derived class
     * SpotLight and change the type later. */
    _light = lock.scene->create_node<SpotLight>();
  }

  _light->set_use_mis(true);
  _light->name = GetId().GetString();

  _object->set_geometry(_light);
  _object->set_random_id(hash_uint2(hash_string(_light->name.c_str()), 0));
  _object->set_visibility(PATH_RAY_VISIBILITY_ALL & ~PATH_RAY_VISIBILITY_CAMERA);

  Shader *const shader = lock.scene->create_node<Shader>();
  array<Node *> used_shaders;
  used_shaders.push_back_slow(shader);
  _light->set_used_shaders(used_shaders);

  /* Create default shader graph */
  PopulateShaderGraph(HdContainerDataSourceHandle(), renderParam);
}

HDCYCLES_NAMESPACE_CLOSE_SCOPE
