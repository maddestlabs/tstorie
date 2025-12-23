/* Helper functions for miniaudio Nim bindings */

#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

/* Set device config fields that are hard to access from Nim */
void ma_device_config_set_callback(ma_device_config* pConfig, ma_device_data_proc callback, void* pUserData) {
    pConfig->dataCallback = callback;
    pConfig->pUserData = pUserData;
}

void ma_device_config_set_playback_format(ma_device_config* pConfig, ma_format format, ma_uint32 channels, ma_uint32 sampleRate) {
    pConfig->playback.format = format;
    pConfig->playback.channels = channels;
    pConfig->sampleRate = sampleRate;
}

void ma_device_config_set_period_size(ma_device_config* pConfig, ma_uint32 periodSizeInFrames) {
    pConfig->periodSizeInFrames = periodSizeInFrames;
}

/* Performance optimization flags */
void ma_device_config_set_performance_profile(ma_device_config* pConfig, ma_performance_profile profile) {
    pConfig->performanceProfile = profile;
}

void ma_device_config_set_no_pre_silenced_output_buffer(ma_device_config* pConfig, ma_bool8 value) {
    pConfig->noPreSilencedOutputBuffer = value;
}

void ma_device_config_set_no_clip(ma_device_config* pConfig, ma_bool8 value) {
    pConfig->noClip = value;
}

void ma_device_config_set_no_fixed_sized_callback(ma_device_config* pConfig, ma_bool8 value) {
    pConfig->noFixedSizedCallback = value;
}

/* Get device info */
ma_uint32 ma_device_get_sample_rate(ma_device* pDevice) {
    return pDevice->sampleRate;
}

ma_uint32 ma_device_get_channels(ma_device* pDevice) {
    return pDevice->playback.channels;
}

void* ma_device_get_user_data(ma_device* pDevice) {
    return pDevice->pUserData;
}
