/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/color_util.h"
#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

ccl_device_noinline void svm_node_combine_color(
    ccl_private float *ccl_restrict stack, const ccl_global SVMNodeCombineColor &ccl_restrict node)
{
  const float r = stack_load(stack, node.red);
  const float g = stack_load(stack, node.green);
  const float b = stack_load(stack, node.blue);

  /* Combine, and convert back to RGB */
  const float3 color = svm_combine_color(node.color_type, make_float3(r, g, b));

  if (stack_valid(node.color_offset)) {
    stack_store_float3(stack, node.color_offset, color);
  }
}

ccl_device_noinline void svm_node_separate_color(
    ccl_private float *ccl_restrict stack,
    const ccl_global SVMNodeSeparateColor &ccl_restrict node)
{
  float3 color = stack_load(stack, node.color);

  /* Convert color space */
  color = svm_separate_color(node.color_type, color);

  if (stack_valid(node.red_offset)) {
    stack_store_float(stack, node.red_offset, color.x);
  }
  if (stack_valid(node.green_offset)) {
    stack_store_float(stack, node.green_offset, color.y);
  }
  if (stack_valid(node.blue_offset)) {
    stack_store_float(stack, node.blue_offset, color.z);
  }
}

CCL_NAMESPACE_END
