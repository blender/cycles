/* SPDX-FileCopyrightText: 2009-2010 Sony Pictures Imageworks Inc., et al. All Rights Reserved.
 * SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Adapted code from Open Shading Language. */

#pragma once

#include "kernel/globals.h"

#include "kernel/svm/math_util.h"
#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

#include "kernel/util/colorspace.h"

CCL_NAMESPACE_BEGIN

/* Blackbody Node */

ccl_device_noinline void svm_node_blackbody(KernelGlobals kg,
                                            ccl_private float *ccl_restrict stack,
                                            const ccl_global SVMNodeBlackbody &ccl_restrict node)
{
  /* Input */
  const float temperature = stack_load(stack, node.temperature);

  float3 color_rgb = rec709_to_rgb(kg, svm_math_blackbody_color_rec709(temperature));
  color_rgb = max(color_rgb, zero_float3());

  stack_store_float3(stack, node.color_offset, color_rgb);
}

CCL_NAMESPACE_END
