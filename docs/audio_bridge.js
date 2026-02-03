// ================================================================
// WEB AUDIO API BRIDGE FOR EMSCRIPTEN
// ================================================================
// Provides audio playback for TStorie WASM builds using Web Audio API

// Emscripten library interface
mergeInto(LibraryManager.library, {
  emAudioInit: function() {
    if (!Module.audioContext) {
      try {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        Module.audioContext = new AudioContext();
        Module.audioSources = [];
        console.log('TStorie Audio: Web Audio API initialized');
      } catch (e) {
        console.error('TStorie Audio: Failed to initialize Web Audio API:', e);
      }
    }
  },
  
  emAudioPlaySample: function(dataPtr, length, sampleRate, volume) {
    if (!Module.audioContext) {
      console.log('TStorie Audio: Audio context not initialized');
      return;
    }
    
    // Resume audio context (needed for Chrome autoplay policy)
    if (Module.audioContext.state === 'suspended') {
      Module.audioContext.resume();
    }
    
    try {
      // Validate inputs
      if (!dataPtr || length <= 0) {
        console.error('TStorie Audio: Invalid audio data - dataPtr:', dataPtr, 'length:', length);
        return;
      }
      
      // Debug: Check HEAP availability
      if (typeof HEAPF32 === 'undefined') {
        console.error('TStorie Audio: HEAPF32 not available');
        return;
      }
      
      // Create buffer from the Nim-generated float32 data
      const audioBuffer = Module.audioContext.createBuffer(1, length, sampleRate);
      
      // Copy data from WASM memory to audio buffer
      const channelData = audioBuffer.getChannelData(0);
      
      // Access WASM heap - dataPtr is a byte offset, we need float32 offset
      const float32Offset = dataPtr >> 2; // Divide by 4 for float32
      
      // Copy from WASM heap to audio buffer
      for (let i = 0; i < length; i++) {
        channelData[i] = HEAPF32[float32Offset + i];
      }
      
      // Create source and gain nodes
      const source = Module.audioContext.createBufferSource();
      const gainNode = Module.audioContext.createGain();
      
      source.buffer = audioBuffer;
      gainNode.gain.value = volume;
      
      // Connect: source -> gain -> destination
      source.connect(gainNode);
      gainNode.connect(Module.audioContext.destination);
      
      // Track active source
      Module.audioSources.push(source);
      
      // Clean up when finished
      source.onended = function() {
        const index = Module.audioSources.indexOf(source);
        if (index > -1) {
          Module.audioSources.splice(index, 1);
        }
      };
      
      // Play
      source.start(0);
    } catch (e) {
      console.error('TStorie Audio: Error playing sample:', e);
    }
  },
  
  emAudioStopAll: function() {
    if (Module.audioSources) {
      Module.audioSources.forEach(function(source) {
        try {
          source.stop();
        } catch (e) {
          // Source might have already stopped
        }
      });
      Module.audioSources = [];
    }
  }
});

// Auto-resume audio context on user interaction (Chrome policy)
if (typeof document !== 'undefined') {
  document.addEventListener('click', function() {
    if (Module.audioContext && Module.audioContext.state === 'suspended') {
      Module.audioContext.resume();
    }
  });
  document.addEventListener('keydown', function() {
    if (Module.audioContext && Module.audioContext.state === 'suspended') {
      Module.audioContext.resume();
    }
  });
}
