/* SPDX-FileCopyrightText: 2009-2010 Sony Pictures Imageworks Inc., et al. All Rights Reserved.
 * SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Adapted code from Open Shading Language. */

#pragma once

#include "kernel/svm/math_util.h"
#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

#include "kernel/util/colorspace.h"

CCL_NAMESPACE_BEGIN

/* Wavelength to RGB */

ccl_device_noinline void svm_node_wavelength(KernelGlobals kg,
                                             ccl_private float *ccl_restrict stack,
                                             const ccl_global SVMNodeWavelength &ccl_restrict node)
{
  const float lambda_nm = stack_load(stack, node.wavelength);

  float3 color = svm_math_wavelength_color_xyz(lambda_nm);
  color = xyz_to_rgb(kg, color);
  color *= 1.0f / 2.52f;  // Empirical scale from lg to make all comps <= 1

  /* Clamp to zero if values are smaller */
  color = max(color, make_float3(0.0f, 0.0f, 0.0f));

  stack_store_float3(stack, node.color_offset, color);
}

CCL_NAMESPACE_END
