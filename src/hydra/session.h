/* SPDX-FileCopyrightText: 2022 NVIDIA Corporation
 * SPDX-FileCopyrightText: 2022 Blender Foundation
 *
 * SPDX-License-Identifier: Apache-2.0 */

#pragma once

#include "hydra/config.h"
#include "util/set.h"
#include "util/thread.h"

#include <pxr/imaging/hd/renderDelegate.h>

HDCYCLES_NAMESPACE_OPEN_SCOPE

struct SceneLock {
  SceneLock(const PXR_NS::HdRenderParam *renderParam);
  ~SceneLock();

  CCL_NS::Scene *scene;

 private:
  CCL_NS::thread_scoped_lock sceneLock;
};

class HdCyclesSession final : public PXR_NS::HdRenderParam {
 public:
  HdCyclesSession(CCL_NS::Session *session_, const bool keep_nodes);
  HdCyclesSession(const CCL_NS::SessionParams &params);
  ~HdCyclesSession() override;

  /* Queue node for deletion on the next UpdateScene(). Must be called with the scene locked. */
  void DeleteNode(CCL_NS::Object *node);
  void DeleteNode(CCL_NS::Geometry *node);
  void DeleteNode(CCL_NS::Shader *node);

  void UpdateScene();

  double GetStageMetersPerUnit() const
  {
    return _stageMetersPerUnit;
  }

  void SetStageMetersPerUnit(const double stageMetersPerUnit)
  {
    _stageMetersPerUnit = stageMetersPerUnit;
  }

  PXR_NS::TfToken GetStageUpAxis() const {
    return _stageUpAxis;
  }

  void SetStageUpAxis(const PXR_NS::TfToken stageUpAxis)
  {
    _stageUpAxis = stageUpAxis;
  }

  PXR_NS::HdRenderPassAovBinding GetDisplayAovBinding() const
  {
    return _displayAovBinding;
  }

  void SetDisplayAovBinding(const PXR_NS::HdRenderPassAovBinding &aovBinding)
  {
    _displayAovBinding = aovBinding;
  }

  const PXR_NS::HdRenderPassAovBindingVector &GetAovBindings() const
  {
    return _aovBindings;
  }

  void SyncAovBindings(const PXR_NS::HdRenderPassAovBindingVector &aovBindings);

  void RemoveAovBinding(PXR_NS::HdRenderBuffer *renderBuffer);

  CCL_NS::Session *session;
  bool keep_nodes;

 private:
  const bool _ownCyclesSession;
  double _stageMetersPerUnit = 0.01;
  PXR_NS::TfToken _stageUpAxis = PXR_NS::TfToken("Y");
  PXR_NS::HdRenderPassAovBindingVector _aovBindings;
  PXR_NS::HdRenderPassAovBinding _displayAovBinding;
  CCL_NS::set<CCL_NS::Object *> _deletedObjects;
  CCL_NS::set<CCL_NS::Geometry *> _deletedGeometry;
  CCL_NS::set<CCL_NS::Shader *> _deletedShaders;

  void FlushDeletedNodes();
};

HDCYCLES_NAMESPACE_CLOSE_SCOPE
