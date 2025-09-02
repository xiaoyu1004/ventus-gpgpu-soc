#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <map>
#include <memory>
#include <new>

#define LOG(level, format, ...)                                                \
  do {                                                                         \
    printf("[" level "] %s:%d " format "\n", __FILE__, __LINE__,               \
           ##__VA_ARGS__);                                                     \
  } while (0)
#define INFO(format, ...) LOG("info", format, ##__VA_ARGS__);
#define WARN(format, ...) LOG("warn", format, ##__VA_ARGS__);
#define ERROR(format, ...) LOG("error", format, ##__VA_ARGS__);
#define FATAL(format, ...) LOG("fatal", format, ##__VA_ARGS__);

typedef uint64_t paddr_t;

class PhysicalMemory {
public:
  PhysicalMemory() {}
  PhysicalMemory(bool auto_alloc, uint64_t pagesize)
      : m_auto_alloc(auto_alloc), m_pagesize(pagesize) {}
  ~PhysicalMemory();

  bool alloc(paddr_t *paddr, uint64_t size);
  bool free(paddr_t paddr);
  bool page_alloc(paddr_t paddr);
  bool page_free(paddr_t paddr);
  bool write(paddr_t paddr, const void *data, const bool mask[], uint64_t size);
  bool write(paddr_t paddr, const void *data, uint64_t size);
  bool read(paddr_t paddr, void *data, uint64_t size) const;
  inline paddr_t get_page_base(paddr_t paddr) const {
    return paddr - paddr % m_pagesize;
  }

private:
  const bool m_auto_alloc = false;
  const uint64_t m_pagesize = 4096;

  std::map<paddr_t, uint8_t *> m_map;
  std::map<paddr_t, uint32_t> m_alloc_records;
};
