# TODO001 — llama.cpp Migration Implementation

## Phase 0 — Context Harvest
- [ ] Review llama.cpp architecture and GGUF format specifications
- [ ] Update ADJACENT_INDEX.md with llama.cpp, Metal, CUDA, and DirectML versions
- [ ] Collect interface contracts from llama.cpp server API and build systems
- [ ] Validate cross-platform build requirements and dependencies
- [ ] **Create fracas.md** for failure tracking using FRACAS methodology
- [ ] Block: Implementation cannot proceed until Phase 0 complete

## Phase 1 — Model Preparation & Docker Baseline
- [ ] **GGUF Model Conversion Pipeline**
  - [ ] Set up HuggingFace to GGUF conversion tools and pipeline
  - [ ] Convert existing models to GGUF format (Q4_K_M primary, Q3_K_M test)
  - [ ] Implement SHA256 checksum validation for model consistency
  - [ ] Create model metadata management and organization system
  - [ ] Test converted models for inference accuracy and compatibility
- [ ] **Docker Baseline Implementation**
  - [ ] Pull and configure ghcr.io/ggerganov/llama.cpp:server image
  - [ ] Set up volume mounts for model access within vault boundary
  - [ ] Configure CPU-only baseline with optimal thread allocation
  - [ ] Implement health checking and container lifecycle management
  - [ ] Integrate Docker service with existing docker-compose.yml
- [ ] **API Endpoint Verification**
  - [ ] Test OpenAI-compatible /v1/chat/completions endpoint
  - [ ] Validate /completion endpoint functionality
  - [ ] Verify response format compatibility with existing clients
  - [ ] Test error handling and status code compliance
  - [ ] Implement API compatibility validation suite
- [ ] **Benchmark Suite Development**
  - [ ] Create standardized prompt suite for journaling and MCP tasks
  - [ ] Implement latency measurement (TTFT, tokens/sec, total time)
  - [ ] Add JSON tool-call validation framework
  - [ ] Create performance baseline collection and reporting
  - [ ] Set up automated regression testing framework
- [ ] Unit tests for model conversion and Docker configuration
- [ ] Integration tests for API compatibility
- [ ] **Document any failures** in fracas.md immediately when encountered
- [ ] **Phase 1 Testing Summary** for handoff to Phase 2

## Phase 2 — Native Platform Optimization
- [ ] **macOS Metal Acceleration**
  - [ ] Build llama.cpp with Metal support using CMake configuration
  - [ ] Test Metal GPU acceleration and memory offloading (-ngl 999)
  - [ ] Optimize thread allocation for Apple Silicon architecture
  - [ ] Validate Metal Performance Shaders integration
  - [ ] Benchmark Metal performance vs Docker baseline
  - [ ] Implement macOS-specific startup and configuration scripts
- [ ] **Linux CUDA Acceleration**
  - [ ] Build llama.cpp with CUDA support and cuBLAS integration
  - [ ] Test CUDA GPU acceleration and VRAM utilization
  - [ ] Optimize CUDA kernel configuration and memory management
  - [ ] Validate multi-GPU support and load balancing
  - [ ] Benchmark CUDA performance vs Docker baseline
  - [ ] Implement Linux-specific startup and configuration scripts
- [ ] **Windows CUDA Acceleration**
  - [ ] Set up Visual Studio build environment with CUDA toolkit
  - [ ] Build llama.cpp with Windows CUDA support
  - [ ] Test CUDA acceleration on Windows with GPU offloading
  - [ ] Optimize Windows-specific threading and memory management
  - [ ] Create PowerShell scripts for Windows deployment
  - [ ] Benchmark Windows CUDA performance vs Docker baseline
- [ ] **Windows DirectML Acceleration** 
  - [ ] Build llama.cpp with DirectML support for broader hardware compatibility
  - [ ] Test DirectML acceleration on various Windows GPU configurations
  - [ ] Validate compatibility with Intel, AMD, and NVIDIA GPUs
  - [ ] Optimize DirectML performance and resource usage
  - [ ] Compare DirectML vs CUDA performance on NVIDIA hardware
  - [ ] Create DirectML-specific deployment and configuration
- [ ] **Hardware Detection and Auto-Optimization**
  - [ ] Implement automatic platform and hardware detection
  - [ ] Create optimal configuration selection based on available hardware
  - [ ] Add fallback mechanisms for unsupported hardware configurations
  - [ ] Implement runtime optimization parameter tuning
  - [ ] Test hardware detection across all target platforms
- [ ] Performance tests across all platforms
- [ ] Cross-platform compatibility validation
- [ ] **Document any failures** in fracas.md immediately when encountered
- [ ] **Phase 2 Testing Summary** for handoff to Phase 3

## Phase 3 — Integration & API Compatibility
- [ ] **Runtime Selection Mechanism**
  - [ ] Implement environment variable-based runtime selection (AI_RUNTIME)
  - [ ] Create unified startup script supporting llamacpp/ollama/docker modes
  - [ ] Add runtime health checking and automatic failover capabilities
  - [ ] Implement graceful runtime switching without data loss
  - [ ] Test runtime selection across all supported platforms
- [ ] **API Compatibility Validation**
  - [ ] Comprehensive endpoint testing vs existing Ollama integration
  - [ ] Validate MCP host integration with new llama.cpp endpoints
  - [ ] Test Open WebUI compatibility with llama.cpp server
  - [ ] Verify tool-calling JSON format compliance and success rates
  - [ ] Implement automated compatibility regression testing
- [ ] **Performance Benchmarking Framework**
  - [ ] Create side-by-side performance comparison suite
  - [ ] Implement automated A/B testing between Ollama and llama.cpp
  - [ ] Add memory usage monitoring and resource consumption analysis
  - [ ] Create performance dashboard and reporting system
  - [ ] Validate performance targets meet or exceed Ollama baseline
- [ ] **Integration with Existing Infrastructure**
  - [ ] Update docker-compose.yml for llama.cpp service integration
  - [ ] Modify journal startup scripts to support runtime selection
  - [ ] Ensure model storage integration with encrypted vault
  - [ ] Update health monitoring and status reporting systems
  - [ ] Test full system integration with all components
- [ ] End-to-end workflow testing across all platforms
- [ ] Integration testing with existing MCP and WebUI components
- [ ] **Document any failures** in fracas.md immediately when encountered
- [ ] **Phase 3 Testing Summary** for handoff to Phase 4

## Phase 4 — Production Deployment & Monitoring
- [ ] **Production Configuration Management**
  - [ ] Create platform-specific production deployment scripts
  - [ ] Implement automated optimal configuration selection
  - [ ] Add production-grade error handling and recovery mechanisms
  - [ ] Create configuration validation and system requirements checking
  - [ ] Implement secure credential and configuration management
- [ ] **Monitoring and Health Checking**
  - [ ] Implement comprehensive health monitoring for llama.cpp server
  - [ ] Add performance metrics collection and alerting
  - [ ] Create automated performance regression detection
  - [ ] Implement resource usage monitoring and optimization alerts
  - [ ] Add logging and diagnostic capabilities for troubleshooting
- [ ] **Rollback and Failover Mechanisms**
  - [ ] Create automated failover to Ollama on llama.cpp failure
  - [ ] Implement instant rollback procedures with environment flags
  - [ ] Add health-based automatic runtime switching
  - [ ] Create complete system state preservation during runtime changes
  - [ ] Test all failure scenarios and recovery procedures
- [ ] **Documentation and User Experience**
  - [ ] Complete cross-platform setup and installation guides
  - [ ] Create troubleshooting documentation for platform-specific issues
  - [ ] Document performance tuning options and recommendations
  - [ ] Create migration guides for existing Ollama users
  - [ ] Add user controls for runtime preferences and optimization
- [ ] Production load testing and stability validation
- [ ] Cross-platform deployment verification
- [ ] **Resolve all critical failure modes** in fracas.md before deployment
- [ ] **Phase 4 Testing Summary** for handoff to deployment

## Initiative Completion
- [ ] **Final Testing Summary** - Comprehensive testing report across all phases
  - [ ] Cross-platform performance validation and comparison
  - [ ] API compatibility verification and regression testing results
  - [ ] Production stability and monitoring effectiveness validation
  - [ ] User experience and documentation quality assessment
- [ ] **Technical Debt Documentation** - Complete technical debt catalog and remediation roadmap
  - [ ] Known platform-specific limitations and workarounds
  - [ ] Future optimization opportunities and performance improvements
  - [ ] Maintenance procedures and update strategies
  - [ ] Community contribution guidelines and development setup
- [ ] **Production Deployment Readiness**
  - [ ] Release preparation and version tagging
  - [ ] Cross-platform distribution packages and installation procedures
  - [ ] User migration documentation and support procedures
  - [ ] Monitoring and alerting production deployment

## Blockers
- **Platform Build Dependencies**: Requires platform-specific build tools (CMake, Visual Studio, CUDA toolkit)
- **Hardware Requirements**: GPU acceleration requires compatible hardware (Metal/CUDA/DirectML)
- **Model Storage**: GGUF models require additional storage within encrypted vault
- **Docker Compatibility**: Baseline testing requires Docker availability on all platforms

## Notes
- **Performance Priority**: All optimizations prioritize speed and efficiency over convenience
- **Cross-Platform Focus**: Consistent behavior and feature parity across macOS, Linux, and Windows
- **API Compatibility**: Seamless drop-in replacement for existing Ollama integration
- **Hardware Utilization**: Maximum utilization of available GPU acceleration on each platform

## FRACAS Integration
- **Failure Tracking**: All platform-specific failures and compatibility issues documented in `fracas.md`
- **Investigation Process**: Follow systematic FRACAS methodology for platform-specific root cause analysis
- **Knowledge Building**: Use failure modes to improve cross-platform compatibility and user experience
- **Status Management**: Track platform-specific issues and resolution approaches

**FRACAS Document Location**: `docs/initiatives/cpp_migration/fracas.md`

## Testing Strategy by Phase

### Phase 1 Testing Focus
- **Model Conversion**: GGUF format validation, inference accuracy, checksum verification
- **Docker Baseline**: Container functionality, API compatibility, performance baseline
- **API Compatibility**: Endpoint testing, response format validation, error handling
- **Benchmark Framework**: Metric accuracy, automated testing, regression detection

### Phase 2 Testing Focus
- **Platform Acceleration**: GPU utilization, performance optimization, hardware compatibility
- **Cross-Platform Builds**: Build system validation, dependency management, platform-specific issues
- **Performance Validation**: Acceleration effectiveness, resource usage, stability testing
- **Hardware Detection**: Automatic optimization, fallback mechanisms, compatibility testing

### Phase 3 Testing Focus
- **Runtime Integration**: Seamless switching, failover mechanisms, compatibility preservation
- **API Validation**: Complete endpoint compatibility, existing client integration, regression testing
- **Performance Comparison**: Benchmarking accuracy, A/B testing effectiveness, metric validation
- **System Integration**: Full workflow testing, component compatibility, infrastructure integration

### Phase 4 Testing Focus
- **Production Deployment**: Stability under load, monitoring effectiveness, error recovery
- **Cross-Platform Validation**: Deployment consistency, platform-specific optimization, user experience
- **Rollback Procedures**: Failover reliability, state preservation, recovery time validation
- **Documentation Quality**: Setup success rate, troubleshooting effectiveness, user satisfaction

## Success Metrics by Phase

### Phase 1 Success Criteria
- [ ] All target models converted to GGUF with validated checksums
- [ ] Docker baseline achieves consistent performance across platforms
- [ ] API compatibility validates 100% endpoint compliance
- [ ] Benchmark suite provides accurate and reproducible metrics

### Phase 2 Success Criteria
- [ ] Native acceleration achieves >20% performance improvement vs Docker baseline
- [ ] Cross-platform builds complete successfully on all target platforms
- [ ] GPU utilization reaches >90% on compatible hardware
- [ ] Hardware detection accurately identifies and optimizes for available acceleration

### Phase 3 Success Criteria
- [ ] Runtime switching completes in <30 seconds with zero downtime
- [ ] API compatibility maintains 100% success rate with existing clients
- [ ] Performance benchmarks meet or exceed Ollama baseline on all platforms
- [ ] System integration preserves all existing functionality

### Phase 4 Success Criteria
- [ ] Production deployment achieves >99% uptime and stability
- [ ] Monitoring detects and responds to issues within 30 seconds
- [ ] Rollback procedures complete in <60 seconds for any failure mode
- [ ] Documentation enables >95% successful setup rate for new users

---

**Document Version**: 1.0  
**Status**: Planning  
**Created**: 2025-01-18  
**Last Updated**: 2025-01-18  
**Owner**: Local Development Team  
**Estimated Timeline**: 28 days (4 weeks)  

**Related Documents**:
- PRD001.md - Product requirements and cross-platform objectives
- RFC001.md - Technical architecture and platform-specific implementation
- fracas.md - Failure tracking and platform-specific issue analysis