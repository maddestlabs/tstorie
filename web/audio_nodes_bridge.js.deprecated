// ================================================================
// WEB AUDIO API BRIDGE FOR NODE-BASED AUDIO
// ================================================================
// Direct bindings to Web Audio API for TStorie's audio node system

mergeInto(LibraryManager.library, {
  emCreateAudioContext: function() {
    if (!Module.tsAudioContext) {
      try {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        Module.tsAudioContext = new AudioContext();
        console.log('TStorie: AudioContext created');
      } catch (e) {
        console.error('TStorie: Failed to create AudioContext:', e);
        return null;
      }
    }
    return Module.tsAudioContext;
  },
  
  emGetDestination: function(ctx) {
    return ctx ? ctx.destination : null;
  },
  
  emGetCurrentTime: function(ctx) {
    return ctx ? ctx.currentTime : 0.0;
  },
  
  emCreateOscillator: function(ctx) {
    if (!ctx) return null;
    try {
      const osc = ctx.createOscillator();
      osc.frequency.value = 440; // Default A4
      osc.type = 'sine';
      return osc;
    } catch (e) {
      console.error('TStorie: Failed to create oscillator:', e);
      return null;
    }
  },
  
  emCreateGain: function(ctx) {
    if (!ctx) return null;
    try {
      const gain = ctx.createGain();
      gain.gain.value = 1.0;
      return gain;
    } catch (e) {
      console.error('TStorie: Failed to create gain node:', e);
      return null;
    }
  },
  
  emCreateBufferSource: function(ctx) {
    if (!ctx) return null;
    try {
      return ctx.createBufferSource();
    } catch (e) {
      console.error('TStorie: Failed to create buffer source:', e);
      return null;
    }
  },
  
  emConnectNodes: function(source, dest) {
    if (!source || !dest) return;
    try {
      source.connect(dest);
    } catch (e) {
      console.error('TStorie: Failed to connect nodes:', e);
    }
  },
  
  emDisconnectNode: function(node) {
    if (!node) return;
    try {
      node.disconnect();
    } catch (e) {
      console.error('TStorie: Failed to disconnect node:', e);
    }
  },
  
  emStartNode: function(node, when) {
    if (!node || !node.start) return;
    try {
      // Resume context if suspended (Chrome autoplay policy)
      if (Module.tsAudioContext && Module.tsAudioContext.state === 'suspended') {
        Module.tsAudioContext.resume();
      }
      node.start(when || 0);
    } catch (e) {
      console.error('TStorie: Failed to start node:', e);
    }
  },
  
  emStopNode: function(node, when) {
    if (!node || !node.stop) return;
    try {
      node.stop(when || 0);
    } catch (e) {
      console.error('TStorie: Failed to stop node:', e);
    }
  },
  
  emSetNodeParam: function(node, paramPtr, value) {
    if (!node) return;
    try {
      const paramName = UTF8ToString(paramPtr);
      
      if (paramName === 'frequency' && node.frequency) {
        node.frequency.value = value;
      } else if (paramName === 'gain' && node.gain) {
        node.gain.value = value;
      } else if (paramName === 'type' && node.type !== undefined) {
        // Map enum value to type string
        const types = ['sine', 'square', 'sawtooth', 'triangle'];
        node.type = types[Math.floor(value)] || 'sine';
      }
    } catch (e) {
      console.error('TStorie: Failed to set node parameter:', e);
    }
  },
  
  emSetBufferData: function(node, dataPtr, length, sampleRate) {
    if (!node || !Module.tsAudioContext) return;
    try {
      // Create audio buffer
      const buffer = Module.tsAudioContext.createBuffer(1, length, sampleRate);
      const channelData = buffer.getChannelData(0);
      
      // Copy from WASM memory
      const float32Offset = dataPtr >> 2;
      for (let i = 0; i < length; i++) {
        channelData[i] = HEAPF32[float32Offset + i];
      }
      
      // Set buffer on source node
      node.buffer = buffer;
    } catch (e) {
      console.error('TStorie: Failed to set buffer data:', e);
    }
  }
});

// Auto-resume AudioContext on user interaction (Chrome policy)
if (typeof document !== 'undefined') {
  const resumeAudio = function() {
    if (Module.tsAudioContext && Module.tsAudioContext.state === 'suspended') {
      Module.tsAudioContext.resume();
    }
  };
  
  document.addEventListener('click', resumeAudio);
  document.addEventListener('keydown', resumeAudio);
}
