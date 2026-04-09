/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"
#include "util/hash.h"

CCL_NAMESPACE_BEGIN

ccl_device_noinline void svm_node_tex_white_noise(
    ccl_private float *ccl_restrict stack,
    const ccl_global SVMNodeTexWhiteNoise &ccl_restrict node)
{
  const float3 vector = stack_load(stack, node.vector);
  const float w = stack_load(stack, node.w);

  if (stack_valid(node.color_offset)) {
    float3 color;
    switch (node.dimensions) {
      case 1:
        color = hash_float_to_float3(w);
        break;
      case 2:
        color = hash_float2_to_float3(make_float2(vector.x, vector.y));
        break;
      case 3:
        color = hash_float3_to_float3(vector);
        break;
      case 4:
        color = hash_float4_to_float3(make_float4(vector, w));
        break;
      default:
        color = make_float3(1.0f, 0.0f, 1.0f);
        kernel_assert(0);
        break;
    }
    stack_store_float3(stack, node.color_offset, color);
  }

  if (stack_valid(node.value_offset)) {
    float value;
    switch (node.dimensions) {
      case 1:
        value = hash_float_to_float(w);
        break;
      case 2:
        value = hash_float2_to_float(make_float2(vector.x, vector.y));
        break;
      case 3:
        value = hash_float3_to_float(vector);
        break;
      case 4:
        value = hash_float4_to_float(make_float4(vector, w));
        break;
      default:
        value = 0.0f;
        kernel_assert(0);
        break;
    }
    stack_store_float(stack, node.value_offset, value);
  }
}

CCL_NAMESPACE_END
