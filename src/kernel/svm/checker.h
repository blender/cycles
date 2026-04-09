/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

/* Checker */

ccl_device float svm_checker(float3 p)
{
  /* avoid precision issues on unit coordinates */
  p.x = (p.x + 0.000001f) * 0.999999f;
  p.y = (p.y + 0.000001f) * 0.999999f;
  p.z = (p.z + 0.000001f) * 0.999999f;

  const int xi = abs(float_to_int(floorf(p.x)));
  const int yi = abs(float_to_int(floorf(p.y)));
  const int zi = abs(float_to_int(floorf(p.z)));

  return ((xi % 2 == yi % 2) == (zi % 2)) ? 1.0f : 0.0f;
}

ccl_device_noinline void svm_node_tex_checker(
    ccl_private float *ccl_restrict stack, const ccl_global SVMNodeTexChecker &ccl_restrict node)
{
  const float3 co = stack_load_float3(stack, node.co);
  const float3 color1 = stack_load(stack, node.color1);
  const float3 color2 = stack_load(stack, node.color2);
  const float scale = stack_load(stack, node.scale);

  const float f = svm_checker(co * scale);

  if (stack_valid(node.color_offset)) {
    stack_store_float3(stack, node.color_offset, (f == 1.0f) ? color1 : color2);
  }
  if (stack_valid(node.fac_offset)) {
    stack_store_float(stack, node.fac_offset, f);
  }
}

CCL_NAMESPACE_END
