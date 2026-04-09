/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/geom/object.h"
#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

/* Vector Transform */

ccl_device_noinline void svm_node_vector_transform(
    KernelGlobals kg,
    ccl_private ShaderData *sd,
    ccl_private float *ccl_restrict stack,
    const ccl_global SVMNodeVectorTransform &ccl_restrict node)
{
  float3 in = stack_load(stack, node.vector_in);

  const NodeVectorTransformType type = node.transform_type;
  const NodeVectorTransformConvertSpace from = node.convert_from;
  const NodeVectorTransformConvertSpace to = node.convert_to;

  Transform tfm;
  const bool is_object = (sd->object != OBJECT_NONE);
  const bool is_normal = (type == NODE_VECTOR_TRANSFORM_TYPE_NORMAL);
  const bool is_direction = (type == NODE_VECTOR_TRANSFORM_TYPE_VECTOR);

  /* From world */
  if (from == NODE_VECTOR_TRANSFORM_CONVERT_SPACE_WORLD) {
    if (to == NODE_VECTOR_TRANSFORM_CONVERT_SPACE_CAMERA) {
      if (is_normal) {
        tfm = kernel_data.cam.cameratoworld;
        in = normalize(transform_direction_transposed(&tfm, in));
      }
      else {
        tfm = kernel_data.cam.worldtocamera;
        in = is_direction ? transform_direction(&tfm, in) : transform_point(&tfm, in);
      }
    }
    else if (to == NODE_VECTOR_TRANSFORM_CONVERT_SPACE_OBJECT && is_object) {
      if (is_normal) {
        object_inverse_normal_transform(kg, sd, &in);
      }
      else if (is_direction) {
        object_inverse_dir_transform(kg, sd, &in);
      }
      else {
        object_inverse_position_transform(kg, sd, &in);
      }
    }
  }

  /* From camera */
  else if (from == NODE_VECTOR_TRANSFORM_CONVERT_SPACE_CAMERA) {
    if (to == NODE_VECTOR_TRANSFORM_CONVERT_SPACE_WORLD ||
        to == NODE_VECTOR_TRANSFORM_CONVERT_SPACE_OBJECT)
    {
      if (is_normal) {
        tfm = kernel_data.cam.worldtocamera;
        in = normalize(transform_direction_transposed(&tfm, in));
      }
      else {
        tfm = kernel_data.cam.cameratoworld;
        in = is_direction ? transform_direction(&tfm, in) : transform_point(&tfm, in);
      }
    }
    if (to == NODE_VECTOR_TRANSFORM_CONVERT_SPACE_OBJECT && is_object) {
      if (is_normal) {
        object_inverse_normal_transform(kg, sd, &in);
      }
      else if (is_direction) {
        object_inverse_dir_transform(kg, sd, &in);
      }
      else {
        object_inverse_position_transform(kg, sd, &in);
      }
    }
  }

  /* From object */
  else if (from == NODE_VECTOR_TRANSFORM_CONVERT_SPACE_OBJECT) {
    if ((to == NODE_VECTOR_TRANSFORM_CONVERT_SPACE_WORLD ||
         to == NODE_VECTOR_TRANSFORM_CONVERT_SPACE_CAMERA) &&
        is_object)
    {
      if (is_normal) {
        object_normal_transform(kg, sd, &in);
      }
      else if (is_direction) {
        object_dir_transform(kg, sd, &in);
      }
      else {
        object_position_transform(kg, sd, &in);
      }
    }
    if (to == NODE_VECTOR_TRANSFORM_CONVERT_SPACE_CAMERA) {
      if (is_normal) {
        tfm = kernel_data.cam.cameratoworld;
        in = normalize(transform_direction_transposed(&tfm, in));
      }
      else {
        tfm = kernel_data.cam.worldtocamera;
        if (is_direction) {
          in = transform_direction(&tfm, in);
        }
        else {
          in = transform_point(&tfm, in);
        }
      }
    }
  }

  /* Output */
  if (stack_valid(node.vector_out_offset)) {
    stack_store_float3(stack, node.vector_out_offset, in);
  }
}

CCL_NAMESPACE_END
