/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

ccl_device_noinline void svm_node_normal(ccl_private float *ccl_restrict stack,
                                         const ccl_global SVMNodeNormal &ccl_restrict node)
{
  const float3 normal = stack_load(stack, node.in_normal);

  float3 direction = make_float3(node.direction_x, node.direction_y, node.direction_z);
  direction = normalize(direction);

  if (stack_valid(node.out_normal_offset)) {
    stack_store_float3(stack, node.out_normal_offset, direction);
  }

  if (stack_valid(node.out_dot_offset)) {
    stack_store_float(stack, node.out_dot_offset, dot(direction, normalize(normal)));
  }
}

CCL_NAMESPACE_END
