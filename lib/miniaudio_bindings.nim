# ================================================================
# MINIAUDIO BINDINGS
# ================================================================
# Direct bindings to miniaudio.h for audio playback and DSP
# miniaudio: https://github.com/mackron/miniaudio
# 
# This provides low-level access to miniaudio's comprehensive
# audio system including:
# - Cross-platform audio device access
# - Node-based audio processing graph
# - Built-in DSP effects (filters, delays, etc.)
# - Waveform generators
# - Audio encoding/decoding
#
# For high-level usage, see audio.nim which wraps these bindings

import std/os

when defined(emscripten):
  # For WASM builds, miniaudio uses Web Audio API under the hood
  {.passC: "-DMA_NO_JACK".}
  {.passC: "-DMA_NO_PULSEAUDIO".}
  {.passC: "-DMA_NO_ALSA".}
  {.passC: "-DMA_NO_COREAUDIO".}
  {.passC: "-DMA_NO_SNDIO".}
  {.passC: "-DMA_NO_AUDIO4".}
  {.passC: "-DMA_NO_OSS".}
  {.passC: "-DMA_ENABLE_ONLY_SPECIFIC_BACKENDS".}
  {.passC: "-DMA_ENABLE_WEBAUDIO".}

# Tell compiler where to find headers
{.passC: "-I" & currentSourcePath.parentDir().}

# Use the helper C file instead of compiling header directly
{.compile: "miniaudio_helper.c".}

const
  MA_SUCCESS* = 0
  MA_ERROR* = -1
  
  # Common sample rates
  MA_SAMPLE_RATE_8000* = 8000
  MA_SAMPLE_RATE_11025* = 11025
  MA_SAMPLE_RATE_22050* = 22050
  MA_SAMPLE_RATE_44100* = 44100
  MA_SAMPLE_RATE_48000* = 48000
  MA_SAMPLE_RATE_88200* = 88200
  MA_SAMPLE_RATE_96000* = 96000

# ================================================================
# CORE TYPES
# ================================================================

type
  ma_result* = cint
  
  ma_uint8* = uint8
  ma_uint16* = uint16
  ma_uint32* = uint32
  ma_uint64* = uint64
  ma_int8* = int8
  ma_int16* = int16
  ma_int32* = int32
  ma_int64* = int64
  ma_bool32* = ma_uint32
  
  ma_channel* = ma_uint8
  
  ma_backend* {.size: sizeof(cint).} = enum
    ma_backend_wasapi
    ma_backend_dsound
    ma_backend_winmm
    ma_backend_coreaudio
    ma_backend_sndio
    ma_backend_audio4
    ma_backend_oss
    ma_backend_pulseaudio
    ma_backend_alsa
    ma_backend_jack
    ma_backend_aaudio
    ma_backend_opensl
    ma_backend_webaudio
    ma_backend_custom
    ma_backend_null
  
  ma_device_type* {.size: sizeof(cint).} = enum
    ma_device_type_playback = 1
    ma_device_type_capture = 2
    ma_device_type_duplex = 3
    ma_device_type_loopback = 4
  
  ma_format* {.size: sizeof(cint).} = enum
    ma_format_unknown = 0
    ma_format_u8 = 1
    ma_format_s16 = 2
    ma_format_s24 = 3
    ma_format_s32 = 4
    ma_format_f32 = 5
  
  ma_standard_channel_map* {.size: sizeof(cint).} = enum
    ma_standard_channel_map_default = 0
    ma_standard_channel_map_microsoft
    ma_standard_channel_map_alsa
    ma_standard_channel_map_rfc3551
    ma_standard_channel_map_flac
    ma_standard_channel_map_vorbis
    ma_standard_channel_map_sound4
    ma_standard_channel_map_sndio
    ma_standard_channel_map_webaudio
  
  ma_stream_format* {.size: sizeof(cint).} = enum
    ma_stream_format_pcm = 0
  
  ma_stream_layout* {.size: sizeof(cint).} = enum
    ma_stream_layout_interleaved = 0
    ma_stream_layout_deinterleaved
  
  ma_dither_mode* {.size: sizeof(cint).} = enum
    ma_dither_mode_none = 0
    ma_dither_mode_rectangle
    ma_dither_mode_triangle
  
  # Waveform types
  ma_waveform_type* {.size: sizeof(cint).} = enum
    ma_waveform_type_sine
    ma_waveform_type_square
    ma_waveform_type_triangle
    ma_waveform_type_sawtooth
  
  # Noise types
  ma_noise_type* {.size: sizeof(cint).} = enum
    ma_noise_type_white
    ma_noise_type_pink
    ma_noise_type_brownian
  
  # Performance profile
  ma_performance_profile* {.size: sizeof(cint).} = enum
    ma_performance_profile_low_latency = 0
    ma_performance_profile_conservative

# ================================================================
# OPAQUE TYPES (Forward declarations)
# ================================================================

type
  ma_context* {.importc: "ma_context", header: "miniaudio.h", incompleteStruct.} = object
  ma_device* {.importc: "ma_device", header: "miniaudio.h", incompleteStruct.} = object
  ma_device_info* {.importc: "ma_device_info", header: "miniaudio.h", incompleteStruct.} = object
  
  # Simplified device config - we'll access it by value
  ma_device_config* {.importc: "ma_device_config", header: "miniaudio.h", bycopy.} = object
  
  # Node graph types
  ma_node_graph* {.importc: "ma_node_graph", header: "miniaudio.h", incompleteStruct.} = object
  ma_node_config* {.importc: "ma_node_config", header: "miniaudio.h", incompleteStruct.} = object
  ma_node_base* {.importc: "ma_node_base", header: "miniaudio.h", incompleteStruct.} = object
  ma_data_source_node* {.importc: "ma_data_source_node", header: "miniaudio.h", incompleteStruct.} = object
  ma_splitter_node* {.importc: "ma_splitter_node", header: "miniaudio.h", incompleteStruct.} = object
  ma_biquad_node* {.importc: "ma_biquad_node", header: "miniaudio.h", incompleteStruct.} = object
  ma_lpf_node* {.importc: "ma_lpf_node", header: "miniaudio.h", incompleteStruct.} = object
  ma_hpf_node* {.importc: "ma_hpf_node", header: "miniaudio.h", incompleteStruct.} = object
  ma_delay_node* {.importc: "ma_delay_node", header: "miniaudio.h", incompleteStruct.} = object
  
  # Waveform and noise generators
  ma_waveform* {.importc: "ma_waveform", header: "miniaudio.h", incompleteStruct.} = object
  ma_waveform_config* {.importc: "ma_waveform_config", header: "miniaudio.h", incompleteStruct.} = object
  ma_noise* {.importc: "ma_noise", header: "miniaudio.h", incompleteStruct.} = object
  ma_noise_config* {.importc: "ma_noise_config", header: "miniaudio.h", incompleteStruct.} = object
  
  # Data source (for feeding PCM data)
  ma_data_source* {.importc: "ma_data_source", header: "miniaudio.h", incompleteStruct.} = object
  ma_audio_buffer* {.importc: "ma_audio_buffer", header: "miniaudio.h", incompleteStruct.} = object
  ma_audio_buffer_config* {.importc: "ma_audio_buffer_config", header: "miniaudio.h", incompleteStruct.} = object

# ================================================================
# CALLBACK TYPES
# ================================================================

type
  ma_device_data_proc* = proc(pDevice: ptr ma_device, pOutput: pointer, 
                               pInput: pointer, frameCount: ma_uint32) {.cdecl.}
  
  ma_device_notification_proc* = proc(pNotification: pointer) {.cdecl.}
  
  ma_stop_proc* = proc(pUserData: pointer) {.cdecl.}

# ================================================================
# CONTEXT (Backend initialization)
# ================================================================

proc ma_context_init*(backends: pointer, backendCount: ma_uint32,
                      pConfig: pointer, pContext: ptr ma_context): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_context_uninit*(pContext: ptr ma_context) 
  {.importc, header: "miniaudio.h".}

# ================================================================
# DEVICE (Audio output/input)
# ================================================================

proc ma_device_config_init*(deviceType: ma_device_type): ma_device_config 
  {.importc, header: "miniaudio.h".}

proc ma_device_init*(pContext: ptr ma_context, pConfig: ptr ma_device_config,
                    pDevice: ptr ma_device): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_device_uninit*(pDevice: ptr ma_device) 
  {.importc, header: "miniaudio.h".}

proc ma_device_start*(pDevice: ptr ma_device): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_device_stop*(pDevice: ptr ma_device): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_device_is_started*(pDevice: ptr ma_device): ma_bool32 
  {.importc, header: "miniaudio.h".}

proc ma_device_set_master_volume*(pDevice: ptr ma_device, volume: cfloat): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_device_get_master_volume*(pDevice: ptr ma_device, pVolume: ptr cfloat): ma_result 
  {.importc, header: "miniaudio.h".}

# ================================================================
# NODE GRAPH
# ================================================================

proc ma_node_graph_init*(pConfig: pointer, pAllocationCallbacks: pointer,
                        pNodeGraph: ptr ma_node_graph): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_node_graph_uninit*(pNodeGraph: ptr ma_node_graph, pAllocationCallbacks: pointer) 
  {.importc, header: "miniaudio.h".}

proc ma_node_graph_read_pcm_frames*(pNodeGraph: ptr ma_node_graph, pFramesOut: pointer,
                                   frameCount: ma_uint64, pFramesRead: ptr ma_uint64): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_node_graph_get_channels*(pNodeGraph: ptr ma_node_graph): ma_uint32 
  {.importc, header: "miniaudio.h".}

# Node base operations
proc ma_node_set_output_bus_volume*(pNode: ptr ma_node_base, outputBusIndex: ma_uint32,
                                   volume: cfloat): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_node_get_output_bus_volume*(pNode: ptr ma_node_base, outputBusIndex: ma_uint32): cfloat 
  {.importc, header: "miniaudio.h".}

proc ma_node_attach_output_bus*(pNode: ptr ma_node_base, outputBusIndex: ma_uint32,
                               pOtherNode: ptr ma_node_base, otherNodeInputBusIndex: ma_uint32): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_node_detach_output_bus*(pNode: ptr ma_node_base, outputBusIndex: ma_uint32): ma_result 
  {.importc, header: "miniaudio.h".}

# ================================================================
# WAVEFORM GENERATOR
# ================================================================

proc ma_waveform_config_init*(format: ma_format, channels: ma_uint32, sampleRate: ma_uint32,
                             waveformType: ma_waveform_type, amplitude: cdouble,
                             frequency: cdouble): ma_waveform_config 
  {.importc, header: "miniaudio.h".}

proc ma_waveform_init*(pConfig: ptr ma_waveform_config, pWaveform: ptr ma_waveform): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_waveform_uninit*(pWaveform: ptr ma_waveform) 
  {.importc, header: "miniaudio.h".}

proc ma_waveform_read_pcm_frames*(pWaveform: ptr ma_waveform, pFramesOut: pointer,
                                 frameCount: ma_uint64, pFramesRead: ptr ma_uint64): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_waveform_set_amplitude*(pWaveform: ptr ma_waveform, amplitude: cdouble): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_waveform_set_frequency*(pWaveform: ptr ma_waveform, frequency: cdouble): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_waveform_set_type*(pWaveform: ptr ma_waveform, waveformType: ma_waveform_type): ma_result 
  {.importc, header: "miniaudio.h".}

# ================================================================
# NOISE GENERATOR
# ================================================================

proc ma_noise_config_init*(format: ma_format, channels: ma_uint32, noiseType: ma_noise_type,
                          seed: ma_int32, amplitude: cdouble): ma_noise_config 
  {.importc, header: "miniaudio.h".}

proc ma_noise_init*(pConfig: ptr ma_noise_config, pAllocationCallbacks: pointer,
                   pNoise: ptr ma_noise): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_noise_uninit*(pNoise: ptr ma_noise, pAllocationCallbacks: pointer) 
  {.importc, header: "miniaudio.h".}

proc ma_noise_read_pcm_frames*(pNoise: ptr ma_noise, pFramesOut: pointer,
                              frameCount: ma_uint64, pFramesRead: ptr ma_uint64): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_noise_set_amplitude*(pNoise: ptr ma_noise, amplitude: cdouble): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_noise_set_seed*(pNoise: ptr ma_noise, seed: ma_int32): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_noise_set_type*(pNoise: ptr ma_noise, noiseType: ma_noise_type): ma_result 
  {.importc, header: "miniaudio.h".}

# ================================================================
# AUDIO BUFFER (For playing generated PCM data)
# ================================================================

proc ma_audio_buffer_config_init*(format: ma_format, channels: ma_uint32, 
                                 frameCount: ma_uint64, pData: pointer,
                                 pAllocationCallbacks: pointer): ma_audio_buffer_config 
  {.importc, header: "miniaudio.h".}

proc ma_audio_buffer_init*(pConfig: ptr ma_audio_buffer_config,
                          pAudioBuffer: ptr ma_audio_buffer): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_audio_buffer_uninit*(pAudioBuffer: ptr ma_audio_buffer) 
  {.importc, header: "miniaudio.h".}

proc ma_audio_buffer_read_pcm_frames*(pAudioBuffer: ptr ma_audio_buffer, pFramesOut: pointer,
                                     frameCount: ma_uint64, loop: ma_bool32): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_audio_buffer_seek_to_pcm_frame*(pAudioBuffer: ptr ma_audio_buffer, frameIndex: ma_uint64): ma_result 
  {.importc, header: "miniaudio.h".}

# ================================================================
# FILTERS (DSP)
# ================================================================

# Low-pass filter
proc ma_lpf_node_init*(pNodeGraph: ptr ma_node_graph, pConfig: pointer,
                      pAllocationCallbacks: pointer, pLpfNode: ptr ma_lpf_node): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_lpf_node_uninit*(pLpfNode: ptr ma_lpf_node, pAllocationCallbacks: pointer) 
  {.importc, header: "miniaudio.h".}

# High-pass filter
proc ma_hpf_node_init*(pNodeGraph: ptr ma_node_graph, pConfig: pointer,
                      pAllocationCallbacks: pointer, pHpfNode: ptr ma_hpf_node): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_hpf_node_uninit*(pHpfNode: ptr ma_hpf_node, pAllocationCallbacks: pointer) 
  {.importc, header: "miniaudio.h".}

# ================================================================
# DELAY
# ================================================================

proc ma_delay_node_init*(pNodeGraph: ptr ma_node_graph, pConfig: pointer,
                        pAllocationCallbacks: pointer, pDelayNode: ptr ma_delay_node): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_delay_node_uninit*(pDelayNode: ptr ma_delay_node, pAllocationCallbacks: pointer) 
  {.importc, header: "miniaudio.h".}

proc ma_delay_node_set_wet*(pDelayNode: ptr ma_delay_node, wet: cfloat): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_delay_node_set_dry*(pDelayNode: ptr ma_delay_node, dry: cfloat): ma_result 
  {.importc, header: "miniaudio.h".}

proc ma_delay_node_set_decay*(pDelayNode: ptr ma_delay_node, decay: cfloat): ma_result 
  {.importc, header: "miniaudio.h".}

# ================================================================
# UTILITY
# ================================================================

proc ma_version*(pMajor: ptr ma_uint32, pMinor: ptr ma_uint32, pRevision: ptr ma_uint32) 
  {.importc, header: "miniaudio.h".}

proc ma_version_string*(): cstring 
  {.importc, header: "miniaudio.h".}

# ================================================================
# HELPER PROCS (Nim-friendly wrappers)
# ================================================================

# C helper functions for config setup
proc ma_device_config_set_callback*(pConfig: ptr ma_device_config, 
                                    callback: ma_device_data_proc,
                                    pUserData: pointer) 
  {.importc.}

proc ma_device_config_set_playback_format*(pConfig: ptr ma_device_config,
                                          format: ma_format, 
                                          channels: ma_uint32,
                                          sampleRate: ma_uint32) 
  {.importc.}

proc ma_device_config_set_period_size*(pConfig: ptr ma_device_config,
                                       periodSizeInFrames: ma_uint32)
  {.importc.}

# Performance optimization helpers
proc ma_device_config_set_performance_profile*(pConfig: ptr ma_device_config,
                                               profile: ma_performance_profile)
  {.importc.}

proc ma_device_config_set_no_pre_silenced_output_buffer*(pConfig: ptr ma_device_config,
                                                          value: ma_bool32)
  {.importc.}

proc ma_device_config_set_no_clip*(pConfig: ptr ma_device_config,
                                   value: ma_bool32)
  {.importc.}

proc ma_device_config_set_no_fixed_sized_callback*(pConfig: ptr ma_device_config,
                                                    value: ma_bool32)
  {.importc.}

proc ma_device_get_user_data*(pDevice: ptr ma_device): pointer
  {.importc.}

proc getVersion*(): string =
  ## Get miniaudio version as a string
  $ma_version_string()

proc checkResult*(result: ma_result, operation: string) =
  ## Check if a miniaudio operation succeeded, raise exception if not
  if result != MA_SUCCESS:
    raise newException(IOError, "miniaudio error in " & operation & ": " & $result)
