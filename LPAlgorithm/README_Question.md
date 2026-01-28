# HX Algorithm FFI

导入Algorithm FFI问题汇总

## 功能特性

## 1、算法目录

```
📁 LPAlgorithm/
├── 📁 deps/
│   └── 📁 lib/
│       ├── 📦 libjpeg.a
│       ├── 📦 libjpeg.a
│       ├── 🔗 libonnxruntime.1.17.3.dylib
│       ├── 🔗 libonnxruntime.dylib
│       ├── 📦 libpng.a
│       ├── 📦 libpng16.a
│       ├── 📦 libquirc.a
│       └── 📦 libZXing.a
├── 📁 include/
│   └── 📁 ffi/
│       └── 📄 ffi_api.h
└── 📦 libHXAlgorithmFFI.a
```

# 2、引入算法包遇到的问题：

## 问题1：打包出来的算法库不是针对ios平台，需要C++重新编译IOS的包：

- 报错如：
```
Building for 'iOS', but linking in dylib (/Users/feixiang/Desktop/TestAlgorithm/TestAlgorithm/LPAlgorithm/deps/lib/libonnxruntime.dylib) built for 'macOS'
```


## 问题2：LPAlgorithm算法打包出来的文件下包含了opencv2库，与IOS本地库中引入的opencv相冲突，导致编译失败：
 
```
Showing Recent Messages Ignoring duplicate libraries: '-lHXAlgorithmFFI', '-lZXing', '-lc++', '-ljpeg', '-lopencv_world', '-lpng', '-lpng16', '-lquirc'
_OBJC_IVAR_$_CvAbstractCamera.defaultAVCaptureVideoOrientation' in:
    /Users/feixiang/Desktop/work/laserpecker-rn/laserpecker-ios-canvas/LPAlgorithm/LPAlgorithm/Libs/LPAlgorithm/deps/lib/libopencv_world.a[252](cap_ios_abstract_camera.mm.o)
    /Users/feixiang/Desktop/work/laserpecker-rn/laserpecker-ios-canvas/LPAlgorithm/Example/Pods/OpenCV/opencv2.framework/Versions/A/opencv2[arm64][413](cap_ios_abstract_camera.o)
duplicate symbol '_OBJC_IVAR_$_CvVideoCamera._delegate' in:
    /Users/feixiang/Desktop/work/laserpecker-rn/laserpecker-ios-canvas/LPAlgorithm/LPAlgorithm/Libs/LPAlgorithm/deps/lib/libopencv_world.a[254](cap_ios_video_camera.mm.o)
... 
89 duplicate symbols
Linker command failed with exit code 1 (use -v to see invocation)

```


## 问题3：
- 打包出来的Algorithm算法（不包含opencv时），xcode中通过cococapod引入了opencv2的库时，方法库调用不到本地cocoapod中Opencv2中的方法
- c++用的opencv库与本地pod中用的opencv的库是不同版本时，提示方法找不到；

```
如：
 Undefined symbols for architecture arm64:
  "cv::GaussianBlur(cv::_InputArray const&, cv::_OutputArray const&, cv::Size_<int>, double, double, int)", 
	... in libHXAlgorithmFFI.a[15](ImageProcessor.o)

  "cv::cvtColor(cv::_InputArray const&, cv::_OutputArray const&, int, int)", referenced from:
      ...
ld: symbol(s) not found for architecture arm64

找不到 cv::GaussianBlur 方法或者 cv::cvtColor方法

```

## 问题4：
- xcode中去除Cococpod中的opencv2，采用Algorithm算法库中的opencv2 (c++打包编译成了libopencv_world.a文件)时，本地编译失败，其它pod库调用不到算法库中的opencv的方法；

 

## 最后解决办法：
- 将本地的opencv版本4.10.0发给C++，C++打包完成后，用cocoapod仓库方式，将C++打出来的libopencv_world.a文件（opencv2库）重新打包一次，再通过pod依赖方式引入； 能确认原来的方法能调用到opencv，算法库Algorithm也能调用到;

- ** 注：引入C++算法下的动态库
仓库Algorithm.podspec中引入C++算法包下所有.a和动态库dylib

```
s.vendored_libraries = [
    'LPAlgorithm/Libs/**/*.a',
    'LPAlgorithm/Libs/**/*.dylib',
]

```















