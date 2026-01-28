# HX Algorithm FFI

一个基于 C++ 的图像处理和计算机视觉算法库，提供 C 语言 FFI（Foreign Function Interface）接口，支持相机对齐、批量填充等功能。

## 功能特性

- **相机对齐（Camera Align）**: 基于相机标定参数和锚点进行图像校正和对齐
- **批量填充（Part Fill）**: 检测和定位零件填充位置
- **深度学习模型支持**: 集成 ONNX Runtime，支持 YOLOv5 等模型
- **跨平台**: 支持 Windows/Linux，提供统一的 C API 接口

## 依赖项

项目使用 Conan 2.x 管理依赖，主要依赖包括：

- **OpenCV 4.10.0**: 图像处理和计算机视觉库
- **ONNX Runtime 1.17.3**: 深度学习模型推理引擎（从 GitHub Releases 下载预编译版本）
- **Eigen3 3.4.0**: 线性代数库
- **ZXing-C++ 2.3.0**: 二维码/条形码检测库

## 使用方法

### 完整示例

以下是一个完整的使用示例，展示了如何使用 API 进行相机对齐和批量填充检测：

```cpp
#include <ffi/ffi_api.h>
#include <opencv2/opencv.hpp>
#include <iostream>
#include <vector>
#include <string>

int main() {
    // 1. 创建句柄
    void* h = nullptr;
    if (HX_Create(&h) != 0 || !h) {
        std::cerr << "HX_Create failed" << std::endl;
        return 1;
    }

    // 2. 准备配置数据
    const std::string dataDir = "./test";
    const std::string imagePath = "./test/test.png";
    const std::string modelPath = "./test/yolov5s-lite.ort";
    
    // 相机标定 JSON（包含内参矩阵和畸变系数）
    const std::string calibJson = R"({
        "result": {
            "state": "success",
            "camera_rectify": {
                "intrinsic_matrix": [[fx, 0, cx], [0, fy, cy], [0, 0, 1]],
                "distortion_coeff": [[k1, k2, p1, p2, k3, k4, k5, k6, s1, s2, s3, s4, tauX, tauY]]
            }
        }
    })";
    
    // 锚点坐标 JSON（4个点的坐标：x1, y1, x2, y2, x3, y3, x4, y4）
    const std::string anchorJson = R"({
        "result": {
            "state": "success",
            "camera_calibration": [x1, y1, x2, y2, x3, y3, x4, y4]
        }
    })";
    
    // 源点坐标 JSON（格式同锚点）
    const std::string srcPtsJson = R"({
        "result": {
            "state": "success",
            "camera_srcpoints": [x1, y1, x2, y2, x3, y3, x4, y4]
        }
    })";

    // 3. 读取输入图像
    cv::Mat img = cv::imread(imagePath);
    if (img.empty()) {
        std::cerr << "Failed to read image: " << imagePath << std::endl;
        HX_Destroy(h);
        return 1;
    }

    // 4. 初始化相机对齐
    const int inputWidth = img.cols;
    const int inputHeight = img.rows;
    const int outputWidth = 2500;   // 输出图像宽度
    const int outputHeight = 1525;  // 输出图像高度
    const int baseHeight = 0;       // 基准高度

    int code = HX_InitAndroid(
        h,
        dataDir.c_str(),
        calibJson.c_str(),
        anchorJson.c_str(),
        srcPtsJson.c_str(),
        inputWidth, inputHeight,
        outputWidth, outputHeight,
        baseHeight
    );
    
    if (code != 0) {
        std::cerr << "HX_InitAndroid failed: " << code << std::endl;
        HX_Destroy(h);
        return 1;
    }

    // 5. 加载模型
    if (HX_LoadAnchorModelFromFile(h, modelPath.c_str(), 2, 0) != 0) {
        std::cerr << "HX_LoadAnchorModelFromFile failed" << std::endl;
        HX_Destroy(h);
        return 1;
    }

    // 6. 执行相机对齐
    // 分配输出缓冲区（根据 InitAndroid 中指定的输出尺寸）
    std::vector<unsigned char> alignedBuf(outputWidth * outputHeight * 3);
    HX_CameraAlignResult alignResult = {
        0,                          // status
        outputWidth,                // width
        outputHeight,               // height
        false,                      // usedLast
        alignedBuf.data()           // data
    };

    int rc = HX_RunCameraAlign(
        h,
        img.data,                   // 输入图像数据
        inputWidth,                 // 图像宽度
        inputHeight,                // 图像高度
        img.channels(),             // 图像通道数（3 或 4）
        0.0f,                       // offset
        &alignResult                // 输出结果
    );

    if (rc != 0 || alignResult.status != 0) {
        std::cerr << "HX_RunCameraAlign failed: rc=" << rc 
                  << ", status=" << alignResult.status << std::endl;
        HX_Destroy(h);
        return 1;
    }

    // 保存对齐后的图像
    cv::Mat aligned(alignResult.height, alignResult.width, CV_8UC3, alignResult.data);
    cv::imwrite("aligned_output.jpg", aligned);

    // 7. 执行批量填充检测
    const int roiLeft = 2060;      // ROI 左边界（-1 表示整图）
    const int roiTop = 976;        // ROI 上边界
    const int roiWidth = 375;      // ROI 宽度
    const int roiHeight = 366;     // ROI 高度
    const float printX = 2251.0f;  // 打印位置 X
    const float printY = 1159.0f;  // 打印位置 Y
    const char* qrText = nullptr;   // 二维码文本（可选，可为 nullptr）

    // 分配结果缓冲区
    const int maxResults = 100;
    std::vector<HX_PartFillItem> items(maxResults);
    HX_PartFillResult fillResult = {
        maxResults,                 // count（容量）
        items.data()                // items（结果数组）
    };

    int prc = HX_RunPartFill(
        h,
        img.data,                   // 输入图像数据
        img.cols,                   // 图像宽度
        img.rows,                   // 图像高度
        img.channels(),             // 图像通道数
        roiLeft, roiTop, roiWidth, roiHeight,  // ROI 区域
        printX, printY,             // 打印位置
        qrText,                     // 二维码文本
        &fillResult                 // 输出结果
    );

    if (prc != 0) {
        std::cerr << "HX_RunPartFill failed: " << prc << std::endl;
    } else {
        std::cout << "检测到 " << fillResult.count << " 个结果:" << std::endl;
        for (int i = 0; i < fillResult.count; ++i) {
            std::cout << "  结果[" << i << "]: "
                      << "质心=(" << fillResult.items[i].centroidX << ", "
                      << fillResult.items[i].centroidY << "), "
                      << "角度=" << fillResult.items[i].angle << std::endl;
        }
    }

    // 8. 清理资源
    HX_Destroy(h);
    return 0;
}
```

## API 参考

### 核心函数

#### `HX_Create`
创建算法句柄。

```cpp
int HX_Create(void** handle);
```

**返回值**: 0 表示成功，非零表示失败。

---

#### `HX_Destroy`
销毁算法句柄，释放资源。

```cpp
void HX_Destroy(void* handle);
```

---

#### `HX_InitAndroid`
初始化相机对齐参数。

```cpp
int HX_InitAndroid(
    void* handle,
    const char* dataDir,
    const char* calibrationJson,
    const char* anchorPointsJson,
    const char* originalImageAnchorPointsJson,
    int inputWidth,
    int inputHeight,
    int outputWidth,
    int outputHeight,
    int baseHeight
);
```

**参数说明**:
- `handle`: 算法句柄
- `dataDir`: 数据目录路径
- `calibrationJson`: 相机标定 JSON 字符串，包含内参矩阵和畸变系数
- `anchorPointsJson`: 锚点坐标 JSON 字符串，格式为 `[x1, y1, x2, y2, x3, y3, x4, y4]`
- `originalImageAnchorPointsJson`: 原始图像锚点坐标 JSON 字符串，格式同上
- `inputWidth`, `inputHeight`: 输入图像尺寸
- `outputWidth`, `outputHeight`: 输出图像尺寸
- `baseHeight`: 基准高度

**返回值**: 0 表示成功，非零表示失败。

---

#### `HX_LoadAnchorModelFromFile`
从文件加载锚点检测模型。

```cpp
int HX_LoadAnchorModelFromFile(
    void* handle,
    const char* modelPath,
    int threadNum,
    int useGpu
);
```

**参数说明**:
- `handle`: 算法句柄
- `modelPath`: ONNX 模型文件路径（.ort 格式）
- `threadNum`: 推理线程数
- `useGpu`: 是否使用 GPU（0=CPU, 1=GPU）

**返回值**: 0 表示成功，非零表示失败。

---

#### `HX_RunCameraAlign`
执行相机对齐处理。

```cpp
typedef struct {
    int status;          // 状态码（0=成功，非0=错误码）
    int width;           // 输出图像宽度
    int height;          // 输出图像高度
    bool usedLast;       // 是否使用上次结果
    unsigned char* data; // 输出图像数据（BGR, 3通道），调用方分配缓冲区
} HX_CameraAlignResult;

int HX_RunCameraAlign(
    void* handle,
    const unsigned char* imageBGR,
    int width,
    int height,
    int channels,
    float offset,
    HX_CameraAlignResult* result
);
```

**参数说明**:
- `handle`: 算法句柄
- `imageBGR`: 输入图像数据（BGR 或 BGRA 格式，数据必须连续无 padding）
- `width`, `height`: 输入图像尺寸
- `channels`: 输入图像通道数（3 或 4）
- `offset`: 偏移量
- `result`: 输出结果结构体
  - 如果 `result->data == nullptr`，则仅探测尺寸，不复制数据
  - 如果 `result->data != nullptr`，则将输出图像数据复制到 `result->data`
  - 输出数据格式为 BGR（3通道），数据连续无 padding

**返回值**: 0 表示成功，非零表示失败。

---

#### `HX_RunPartFill`
执行批量填充检测。

```cpp
typedef struct {
    float centroidX;  // 质心 X 坐标
    float centroidY;  // 质心 Y 坐标
    float angle;      // 角度
} HX_PartFillItem;

typedef struct {
    int count;                // 检测到的结果数量
    HX_PartFillItem* items;   // 结果数组（调用方分配）
} HX_PartFillResult;

int HX_RunPartFill(
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
    HX_PartFillResult* result
);
```

**参数说明**:
- `handle`: 算法句柄
- `imageBGR`: 输入图像数据（BGR 或 BGRA 格式，数据必须连续无 padding）
- `width`, `height`: 输入图像尺寸
- `channels`: 输入图像通道数（3 或 4）
- `roiLeft`, `roiTop`, `roiWidth`, `roiHeight`: ROI 区域（设置 `roiLeft=roiTop=-1` 表示无 ROI，使用整图）
- `printX`, `printY`: 打印位置坐标
- `qrText`: 二维码文本（可选，可为 `nullptr`）
- `result`: 输出结果结构体
  - `result->count` 应设置为数组容量，函数会更新为实际数量
  - `result->items` 为结果数组，调用方需要预先分配足够大的缓冲区

**返回值**: 0 表示成功，非零表示失败。

## 配置文件格式

### 相机标定 JSON (`calibrationJson`)

```json
{
    "result": {
        "state": "success",
        "camera_rectify": {
            "intrinsic_matrix": [
                [fx, 0, cx],
                [0, fy, cy],
                [0, 0, 1]
            ],
            "distortion_coeff": [
                [k1, k2, p1, p2, k3, k4, k5, k6, s1, s2, s3, s4, tauX, tauY]
            ]
        }
    }
}
```

### 锚点 JSON (`anchorPointsJson`)

```json
{
    "result": {
        "state": "success",
        "camera_calibration": [
            x1, y1, x2, y2, x3, y3, x4, y4
        ]
    }
}
```

### 源点 JSON (`originalImageAnchorPointsJson`)

格式与锚点 JSON 相同。

