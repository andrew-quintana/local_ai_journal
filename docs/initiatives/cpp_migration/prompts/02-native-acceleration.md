# Native Platform Acceleration Implementation Prompt

**Phase**: Native Platform Optimization  
**Component**: Metal, CUDA, and DirectML Hardware Acceleration  
**Reference**: RFC001.md, TODO001.md  

## 🎯 **Objective**
Implement native hardware acceleration for macOS (Metal), Linux (CUDA), and Windows (CUDA/DirectML) with optimal performance tuning.

## 🔧 **Functions to Implement**

```bash
# platform_optimizer.sh - Cross-platform acceleration
detect_platform_hardware() -> {metal|cuda|directml|cpu}
build_metal_optimized() -> build_result
build_cuda_optimized() -> build_result  
build_directml_optimized() -> build_result
optimize_for_hardware(hardware_type) -> optimization_config

# performance_tuner.py - Hardware-specific optimization
class PerformanceTuner:
    def optimize_metal_params() -> MetalConfig
    def optimize_cuda_params() -> CudaConfig
    def optimize_directml_params() -> DirectMLConfig
    def benchmark_acceleration(config) -> PerformanceMetrics
```

## 🛡️ **Platform Implementation Guidelines**

### macOS Metal Acceleration
- Build with GGML_METAL=ON for Apple Silicon optimization
- GPU offloading with -ngl 999 for maximum acceleration
- Optimal thread allocation using physical core count
- Metal Performance Shaders integration validation

### Linux CUDA Acceleration  
- Build with GGML_CUDA=ON and cuBLAS integration
- CUDA kernel optimization and memory management
- Multi-GPU support and load balancing
- VRAM utilization monitoring and optimization

### Windows CUDA/DirectML
- Visual Studio build environment with CUDA toolkit
- DirectML alternative for broader hardware compatibility
- PowerShell deployment scripts and configuration
- GPU compatibility testing across vendors (NVIDIA/AMD/Intel)

## 📚 **Reference Documents**
- **RFC001.md**: Platform-specific build configurations and optimization parameters
- **TODO001.md**: Hardware detection requirements and performance targets

## 🧪 **Testing Requirements**
1. Test acceleration effectiveness vs Docker baseline (>20% improvement)
2. Validate GPU utilization reaches >90% on compatible hardware
3. Test cross-platform build consistency and compatibility
4. Verify automatic hardware detection and optimization selection

---

**Document Version**: 1.0  
**Created**: 2025-01-18  
**Phase**: Native Platform Optimization  
**Priority**: High