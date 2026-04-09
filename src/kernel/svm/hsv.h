/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

#include "util/color.h"

CCL_NAMESPACE_BEGIN

ccl_device_noinline void svm_node_hsv(ccl_private float *ccl_restrict stack,
                                      const ccl_global SVMNodeHSV &ccl_restrict node)
{
  const float fac = stack_load(stack, node.fac);
  const float3 in_color = stack_load(stack, node.color);
  float3 color = in_color;

  const float hue = stack_load(stack, node.hue);
  const float sat = stack_load(stack, node.sat);
  const float val = stack_load(stack, node.val);

  color = rgb_to_hsv(color);

  color.x = fractf(color.x + hue + 0.5f);
  color.y = saturatef(color.y * sat);
  color.z *= val;

  color = hsv_to_rgb(color);

  color.x = fac * color.x + (1.0f - fac) * in_color.x;
  color.y = fac * color.y + (1.0f - fac) * in_color.y;
  color.z = fac * color.z + (1.0f - fac) * in_color.z;

  /* Clamp color to prevent negative values caused by over saturation. */
  color.x = max(color.x, 0.0f);
  color.y = max(color.y, 0.0f);
  color.z = max(color.z, 0.0f);

  if (stack_valid(node.out_color_offset)) {
    stack_store_float3(stack, node.out_color_offset, color);
  }
}

CCL_NAMESPACE_END
