/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

ccl_device float invert(const float color, const float factor)
{
  return factor * (1.0f - color) + (1.0f - factor) * color;
}

ccl_device_noinline void svm_node_invert(ccl_private float *ccl_restrict stack,
                                         const ccl_global SVMNodeInvert &ccl_restrict node)
{
  const float factor = stack_load(stack, node.fac);
  float3 color = stack_load(stack, node.color);

  color.x = invert(color.x, factor);
  color.y = invert(color.y, factor);
  color.z = invert(color.z, factor);

  if (stack_valid(node.out_offset)) {
    stack_store_float3(stack, node.out_offset, color);
  }
}

CCL_NAMESPACE_END
