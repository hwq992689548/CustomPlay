// FFI public C API
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#  ifndef FFI_API
#    define FFI_API __declspec(dllexport)
#  endif
#else
#  ifndef FFI_API
#    define FFI_API
#  endif
#endif

// 句柄生命周期
FFI_API int HX_Create(void** handle);
FFI_API void HX_Destroy(void* handle);

// 对应 CameraFunction::init_android
FFI_API int HX_InitAndroid(
    void* handle,
    const char* dataDir,
    const char* calibrationJson,
    const char* anchorPointsJson,
    const char* originalImageAnchorPointsJson,
    int inputWidth,
    int inputHeight,
    int outputWidth,
    int outputHeight,
    int baseHeight);

// 加载锚点检测模型（从文件）
FFI_API int HX_LoadAnchorModelFromFile(
    void* handle,
    const char* modelPath,
    int threadNum,
    int useGpu /* 0/1 */);

// 相机对齐结果结构体
typedef struct {
    int status;          // 状态码（0=成功，非0=错误码）
    int width;           // 输出图像宽度
    int height;          // 输出图像高度
    bool usedLast;        // 是否使用上次结果 (0/1)
    unsigned char* data; // 输出图像数据（BGR, 3通道），调用方分配缓冲区（至少 width * height * 3 字节）
                         // 如果为 nullptr，则仅探测尺寸，不复制数据
                         // 数据必须连续（无 padding）
} HX_CameraAlignResult;

// 对应 CameraFunction::RunCameraAlign
// imageBGR: 输入图像（BGR, 8UC3 或 BGRA, 8UC4），数据必须连续（无 padding）
// channels: 输入图像通道数（3 或 4）
// result:   输出结果结构体
//           - 如果 result->data == nullptr，则仅探测尺寸，不复制数据
//           - 如果 result->data != nullptr，则将输出图像数据复制到 result->data
//           - 输出数据格式为 BGR (3通道)，数据连续（无 padding）
FFI_API int HX_RunCameraAlign(
    void* handle,
    const unsigned char* imageBGR,
    int width,
    int height,
    int channels,
    float offset,
    HX_CameraAlignResult* result);

// 批量填充单个结果结构体（对应 PartClassificationLogicalCode::Result）
typedef struct {
    float centroidX;        // 质心 X 坐标
    float centroidY;        // 质心 Y 坐标
    float angle;            // 角度
} HX_PartFillItem;

// 批量填充结果结构体
typedef struct {
    int count;                      // 检测到的结果数量
    HX_PartFillItem* items;        // 结果数组（调用方分配，大小为 count）
                                    // 如果为 nullptr，则仅探测数量，写入 result->count
} HX_PartFillResult;

// PartFill interface (C ABI)
// imageBGR: input image buffer (BGR, 8UC3 或 BGRA, 8UC4)，数据必须连续（无 padding）
// channels: 输入图像通道数（3 或 4）
// ROI: left, top, width, height (pixels). Set left=top=-1 to indicate no ROI
// printX/printY: printing point in image coordinates
// qrText: optional null-terminated UTF-8 string (can be nullptr)
// visualize: 0/1
// result: output result structure
//         - 如果 result->items == nullptr，则仅探测数量，写入 result->count
//         - 如果 result->items != nullptr，则填充结果数据到 result->items 数组
//         - result->count 应设置为数组容量，函数会更新为实际数量
FFI_API int HX_RunPartFill(
    void* handle,
    const unsigned char* imageBGR,
    int width,
    int height,
    int channels,
    int roiLeft,
    int roiTop,
    int roiWidth,
    int roiHeight,
    float printX,
    float printY,
    const char* qrText,
    HX_PartFillResult* result);

#ifdef __cplusplus
}
#endif


