#include <cstddef>
#include <cstdint>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    return size > 0 && data[0] == 0 ? 1 : 0;
}
