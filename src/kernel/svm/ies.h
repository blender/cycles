/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

#include "kernel/util/ies.h"

CCL_NAMESPACE_BEGIN

ccl_device_noinline void svm_node_ies(KernelGlobals kg,
                                      ccl_private ShaderData * /*sd*/,
                                      ccl_private float *stack,
                                      const ccl_global SVMNodeIES &ccl_restrict node)
{
  float3 vector = stack_load_float3(stack, node.vector_offset);
  const float strength = stack_load(stack, node.strength);

  vector = normalize(vector);
  const float v_angle = safe_acosf(-vector.z);
  const float h_angle = atan2f(vector.x, vector.y) + M_PI_F;

  const float fac = strength * kernel_ies_interp(kg, node.slot, h_angle, v_angle);

  if (stack_valid(node.fac_offset)) {
    stack_store_float(stack, node.fac_offset, fac);
  }
}

CCL_NAMESPACE_END
