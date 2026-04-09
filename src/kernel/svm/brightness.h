/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/color_util.h"
#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

ccl_device_noinline void svm_node_brightness(ccl_private float *ccl_restrict stack,
                                             const ccl_global SVMNodeBrightContrast &ccl_restrict
                                                 node)
{
  float3 color = stack_load(stack, node.color);
  const float brightness = stack_load(stack, node.bright);
  const float contrast = stack_load(stack, node.contrast);

  color = svm_brightness_contrast(color, brightness, contrast);

  if (stack_valid(node.out_offset)) {
    stack_store_float3(stack, node.out_offset, color);
  }
}

CCL_NAMESPACE_END
