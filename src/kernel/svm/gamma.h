/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/math_util.h"
#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

ccl_device_noinline void svm_node_gamma(ccl_private float *ccl_restrict stack,
                                        const ccl_global SVMNodeGamma &ccl_restrict node)
{
  float3 color = stack_load(stack, node.color);
  const float gamma = stack_load(stack, node.gamma);

  color = svm_math_gamma_color(color, gamma);

  if (stack_valid(node.out_offset)) {
    stack_store_float3(stack, node.out_offset, color);
  }
}

CCL_NAMESPACE_END
