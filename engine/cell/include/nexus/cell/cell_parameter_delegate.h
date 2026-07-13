#pragma once

// CELL Parameter Delegate — Active Experimentation Interface
//
// Implemented by PhysicsWorld, the gameplay layer, or any other subsystem that
// exposes tuneable parameters to CELL. The delegate decouples CELL from the
// concrete engine types, allowing it to nudge parameters within safe bounds
// without a compile-time dependency on the physics or gameplay libraries.

#include <string>

namespace nexus::cell {

class CellParameterDelegate {
public:
  virtual ~CellParameterDelegate() = default;

  /// Set a named parameter to the given value.
  /// The implementation is responsible for clamping to physical limits.
  virtual void setParam(const std::string& name, double value) = 0;

  /// Retrieve the current value of a named parameter.
  /// Returns 0.0 if the name is not recognised.
  virtual double getParam(const std::string& name) const = 0;
};

} // namespace nexus::cell
