/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

/* Vector Rotate */

ccl_device_noinline void svm_node_vector_rotate(
    ccl_private float *ccl_restrict stack, const ccl_global SVMNodeVectorRotate &ccl_restrict node)
{
  if (stack_valid(node.result_offset)) {

    const float3 vector = stack_load(stack, node.vector);
    const float3 center = stack_load(stack, node.center);
    float3 result = make_float3(0.0f, 0.0f, 0.0f);

    if (node.rotate_type == NODE_VECTOR_ROTATE_TYPE_EULER_XYZ) {
      const float3 rotation = stack_load(stack, node.rotation);  // Default XYZ.
      const Transform rotationTransform = euler_to_transform(rotation);
      if (node.invert) {
        result = transform_direction_transposed(&rotationTransform, vector - center) + center;
      }
      else {
        result = transform_direction(&rotationTransform, vector - center) + center;
      }
    }
    else {
      float3 axis;
      float axis_length;
      switch (node.rotate_type) {
        case NODE_VECTOR_ROTATE_TYPE_AXIS_X:
          axis = make_float3(1.0f, 0.0f, 0.0f);
          axis_length = 1.0f;
          break;
        case NODE_VECTOR_ROTATE_TYPE_AXIS_Y:
          axis = make_float3(0.0f, 1.0f, 0.0f);
          axis_length = 1.0f;
          break;
        case NODE_VECTOR_ROTATE_TYPE_AXIS_Z:
          axis = make_float3(0.0f, 0.0f, 1.0f);
          axis_length = 1.0f;
          break;
        default:
          axis = stack_load(stack, node.axis);
          axis_length = len(axis);
          break;
      }
      float angle = stack_load(stack, node.angle);
      angle = node.invert ? -angle : angle;
      result = (axis_length != 0.0f) ?
                   rotate_around_axis(vector - center, axis / axis_length, angle) + center :
                   vector;
    }

    stack_store_float3(stack, node.result_offset, result);
  }
}

CCL_NAMESPACE_END
