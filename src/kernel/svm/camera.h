/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "kernel/globals.h"

#include "kernel/svm/node_types.h"
#include "kernel/svm/util.h"

CCL_NAMESPACE_BEGIN

ccl_device_noinline void svm_node_camera(KernelGlobals kg,
                                         ccl_private ShaderData *sd,
                                         ccl_private float *ccl_restrict stack,
                                         const ccl_global SVMNodeCamera &ccl_restrict node)
{
  const Transform tfm = kernel_data.cam.worldtocamera;
  const float3 vector = transform_point(&tfm, sd->P);
  const float zdepth = vector.z;
  const float distance = len(vector);

  if (stack_valid(node.vector_offset)) {
    stack_store_float3(stack, node.vector_offset, normalize(vector));
  }

  if (stack_valid(node.zdepth_offset)) {
    stack_store_float(stack, node.zdepth_offset, zdepth);
  }

  if (stack_valid(node.distance_offset)) {
    stack_store_float(stack, node.distance_offset, distance);
  }
}

CCL_NAMESPACE_END
