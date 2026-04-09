/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

/* NOTE: svm_ramp.h, svm_ramp_util.h and node_ramp_util.h must stay consistent */

ccl_device_inline float fetch_float(KernelGlobals kg, const int offset)
{
  return __uint_as_float(kernel_data_fetch(svm_nodes, offset));
}

ccl_device_inline float float_ramp_lookup(KernelGlobals kg,
                                          const int offset,
                                          float f,
                                          bool interpolate,
                                          bool extrapolate,
                                          const int table_size)
{
  if ((f < 0.0f || f > 1.0f) && extrapolate) {
    float t0;
    float dy;
    if (f < 0.0f) {
      t0 = fetch_float(kg, offset);
      dy = t0 - fetch_float(kg, offset + 1);
      f = -f;
    }
    else {
      t0 = fetch_float(kg, offset + table_size - 1);
      dy = t0 - fetch_float(kg, offset + table_size - 2);
      f = f - 1.0f;
    }
    return t0 + dy * f * (table_size - 1);
  }

  f = saturatef(f) * (table_size - 1);

  /* clamp int as well in case of NaN */
  const int i = clamp(float_to_int(f), 0, table_size - 1);
  const float t = f - (float)i;

  float a = fetch_float(kg, offset + i);

  if (interpolate && t > 0.0f) {
    a = (1.0f - t) * a + t * fetch_float(kg, offset + i + 1);
  }

  return a;
}

ccl_device_inline float4 rgb_ramp_lookup(KernelGlobals kg,
                                         const int offset,
                                         float f,
                                         bool interpolate,
                                         bool extrapolate,
                                         const int table_size)
{
  if ((f < 0.0f || f > 1.0f) && extrapolate) {
    float4 t0;
    float4 dy;
    if (f < 0.0f) {
      t0 = svm_node_get_data_float4(kg, offset);
      dy = t0 - svm_node_get_data_float4(kg, offset + 4);
      f = -f;
    }
    else {
      t0 = svm_node_get_data_float4(kg, offset + (table_size - 1) * 4);
      dy = t0 - svm_node_get_data_float4(kg, offset + (table_size - 2) * 4);
      f = f - 1.0f;
    }
    return t0 + dy * f * (table_size - 1);
  }

  f = saturatef(f) * (table_size - 1);

  /* clamp int as well in case of NaN */
  const int i = clamp(float_to_int(f), 0, table_size - 1);
  const float t = f - (float)i;

  float4 a = svm_node_get_data_float4(kg, offset + i * 4);

  if (interpolate && t > 0.0f) {
    a = (1.0f - t) * a + t * svm_node_get_data_float4(kg, offset + (i + 1) * 4);
  }

  return a;
}

ccl_device_noinline int svm_node_rgb_ramp(KernelGlobals kg,
                                          ccl_private float *stack,
                                          const ccl_global SVMNodeRGBRamp &node,
                                          int offset)
{
  const float fac = stack_load(stack, node.fac);
  const float4 color = rgb_ramp_lookup(kg, offset, fac, node.interpolate, false, node.table_size);

  if (stack_valid(node.color_offset)) {
    stack_store_float3(stack, node.color_offset, make_float3(color));
  }
  if (stack_valid(node.alpha_offset)) {
    stack_store_float(stack, node.alpha_offset, color.w);
  }

  offset += node.table_size * 4;
  return offset;
}

ccl_device_noinline int svm_node_curves(KernelGlobals kg,
                                        ccl_private float *stack,
                                        const ccl_global SVMNodeCurves &node,
                                        int offset)
{
  const float fac = stack_load(stack, node.fac);
  float3 color = stack_load(stack, node.color);

  const float range_x = node.max_x - node.min_x;
  const float3 relpos = (color - make_float3(node.min_x, node.min_x, node.min_x)) / range_x;

  const float r = rgb_ramp_lookup(kg, offset, relpos.x, true, node.extrapolate, node.table_size).x;
  const float g = rgb_ramp_lookup(kg, offset, relpos.y, true, node.extrapolate, node.table_size).y;
  const float b = rgb_ramp_lookup(kg, offset, relpos.z, true, node.extrapolate, node.table_size).z;

  color = (1.0f - fac) * color + fac * make_float3(r, g, b);
  stack_store_float3(stack, node.out_offset, color);

  offset += node.table_size * 4;
  return offset;
}

ccl_device_noinline int svm_node_curve(KernelGlobals kg,
                                       ccl_private float *stack,
                                       const ccl_global SVMNodeFloatCurve &node,
                                       int offset)
{
  const float fac = stack_load(stack, node.fac);
  float in = stack_load(stack, node.value_in);

  const float range = node.max_x - node.min_x;
  const float relpos = (in - node.min_x) / range;

  const float v = float_ramp_lookup(kg, offset, relpos, true, node.extrapolate, node.table_size);

  in = (1.0f - fac) * in + fac * v;
  stack_store_float(stack, node.out_offset, in);

  offset += node.table_size;
  return offset;
}

CCL_NAMESPACE_END
