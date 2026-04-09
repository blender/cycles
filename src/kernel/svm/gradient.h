/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

/* Gradient */

ccl_device float svm_gradient(const float3 p, NodeGradientType type)
{
  float x;
  float y;
  float z;

  x = p.x;
  y = p.y;
  z = p.z;

  if (type == NODE_BLEND_LINEAR) {
    return x;
  }
  if (type == NODE_BLEND_QUADRATIC) {
    const float r = fmaxf(x, 0.0f);
    return r * r;
  }
  if (type == NODE_BLEND_EASING) {
    const float r = fminf(fmaxf(x, 0.0f), 1.0f);
    const float t = r * r;

    return (3.0f * t - 2.0f * t * r);
  }
  if (type == NODE_BLEND_DIAGONAL) {
    return (x + y) * 0.5f;
  }
  if (type == NODE_BLEND_RADIAL) {
    return atan2f(y, x) / M_2PI_F + 0.5f;
  }

  /* Bias a little bit for the case where p is a unit length vector,
   * to get exactly zero instead of a small random value depending
   * on float precision. */
  const float r = fmaxf(0.999999f - sqrtf(x * x + y * y + z * z), 0.0f);

  if (type == NODE_BLEND_QUADRATIC_SPHERE) {
    return r * r;
  }
  if (type == NODE_BLEND_SPHERICAL) {
    return r;
  }

  return 0.0f;
}

ccl_device_noinline void svm_node_tex_gradient(
    ccl_private float *ccl_restrict stack, const ccl_global SVMNodeTexGradient &ccl_restrict node)
{
  const float3 co = stack_load_float3(stack, node.co);

  float f = svm_gradient(co, node.gradient_type);
  f = saturatef(f);

  if (stack_valid(node.fac_offset)) {
    stack_store_float(stack, node.fac_offset, f);
  }
  if (stack_valid(node.color_offset)) {
    stack_store_float3(stack, node.color_offset, make_float3(f, f, f));
  }
}

CCL_NAMESPACE_END
