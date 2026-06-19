#pragma once

#include <optional>
#include <string>
#include <utility>

namespace nexus {

template <typename T>
class Result {
public:
  static auto ok(T value) -> Result<T> { return Result<T>(std::move(value)); }
  static auto err(std::string error) -> Result<T> { return Result<T>(std::move(error)); }

  [[nodiscard]] auto isOk() const -> bool { return m_value.has_value(); }
  [[nodiscard]] auto isErr() const -> bool { return !m_value.has_value(); }
  [[nodiscard]] auto value() const -> const T& { return *m_value; }
  [[nodiscard]] auto value() -> T& { return *m_value; }
  [[nodiscard]] auto error() const -> const std::string& { return m_error; }

private:
  explicit Result(T value) : m_value(std::move(value)) {}
  explicit Result(std::string error) : m_error(std::move(error)) {}

  std::optional<T> m_value;
  std::string m_error;
};

template <>
class Result<void> {
public:
  static auto ok() -> Result<void> { return Result<void>(true, {}); }
  static auto err(std::string error) -> Result<void> { return Result<void>(false, std::move(error)); }

  [[nodiscard]] auto isOk() const -> bool { return m_ok; }
  [[nodiscard]] auto isErr() const -> bool { return !m_ok; }
  [[nodiscard]] auto error() const -> const std::string& { return m_error; }

private:
  Result(bool ok, std::string error) : m_ok(ok), m_error(std::move(error)) {}

  bool m_ok{false};
  std::string m_error;
};

} // namespace nexus
