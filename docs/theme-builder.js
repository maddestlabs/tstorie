/**
 * TStorie Theme Builder Utility
 * 
 * Helper functions for building custom theme URLs
 * Can be used in HTML pages to create theme pickers
 */

window.TStorieThemes = {
  /**
   * Parse URL params and get theme parameter
   */
  getThemeParam() {
    const params = new URLSearchParams(window.location.search);
    return params.get('theme') || 'neotopia';
  },

  /**
   * Get all available built-in theme names
   */
  builtInThemes: [
    'catppuccin', 'nord', 'dracula', 'outrun', 'alleycat',
    'terminal', 'solardark', 'solarlight', 'neotopia', 'neonopia',
    'coffee', 'stonegarden', 'wat'
  ],

  /**
   * Validate hex color string (with or without #)
   * Returns normalized 6-char hex or null
   */
  validateHexColor(color) {
    if (!color) return null;
    
    // Remove # if present
    color = color.replace(/^#/, '');
    
    // Check if valid hex
    if (!/^[0-9A-Fa-f]{6}$/.test(color)) {
      return null;
    }
    
    return color.toUpperCase();
  },

  /**
   * Parse custom theme string
   * Format: #RRGGBB#RRGGBB#RRGGBB#RRGGBB#RRGGBB#RRGGBB#RRGGBB
   * Returns object with color properties or null
   */
  parseCustomTheme(themeString) {
    if (!themeString || !themeString.startsWith('#')) {
      return null;
    }

    const parts = themeString.split('#').filter(p => p.length > 0);
    
    if (parts.length !== 7) {
      return null;
    }

    // Validate all colors
    const colors = parts.map(p => this.validateHexColor(p));
    if (colors.some(c => c === null)) {
      return null;
    }

    return {
      bgPrimary: colors[0],
      bgSecondary: colors[1],
      fgPrimary: colors[2],
      fgSecondary: colors[3],
      accent1: colors[4],
      accent2: colors[5],
      accent3: colors[6]
    };
  },

  /**
   * Build theme URL parameter from color object
   * Input: {bgPrimary: "001111", bgSecondary: "09343a", ...}
   * Output: "#001111#09343a#e0e0e0#909090#00d98e#ffff00#ff006e"
   */
  buildThemeString(colors) {
    const parts = [
      this.validateHexColor(colors.bgPrimary),
      this.validateHexColor(colors.bgSecondary),
      this.validateHexColor(colors.fgPrimary),
      this.validateHexColor(colors.fgSecondary),
      this.validateHexColor(colors.accent1),
      this.validateHexColor(colors.accent2),
      this.validateHexColor(colors.accent3)
    ];

    // Check all parts are valid
    if (parts.some(p => p === null)) {
      return null;
    }

    return '#' + parts.join('#');
  },

  /**
   * Build complete URL with theme parameter
   * Options:
   *   - theme: string (built-in name or hex string)
   *   - content: string (optional content param)
   *   - fontsize: number (optional)
   *   - shader: string (optional)
   *   - baseUrl: string (optional, defaults to current page)
   */
  buildUrl(options) {
    const url = new URL(options.baseUrl || window.location.href);
    const params = new URLSearchParams();

    // Add theme param
    if (options.theme) {
      params.set('theme', options.theme);
    }

    // Add optional params
    if (options.content) {
      params.set('content', options.content);
    }
    if (options.fontsize) {
      params.set('fontsize', options.fontsize.toString());
    }
    if (options.shader) {
      params.set('shader', options.shader);
    }

    // Build URL without search params first, then add them
    url.search = params.toString();
    return url.toString();
  },

  /**
   * Copy theme URL to clipboard
   */
  async copyThemeUrl(themeString) {
    const url = this.buildUrl({ theme: themeString });
    try {
      await navigator.clipboard.writeText(url);
      console.log('✓ Theme URL copied to clipboard:', url);
      return true;
    } catch (e) {
      console.error('Failed to copy to clipboard:', e);
      return false;
    }
  },

  /**
   * Convert RGB tuple to hex
   */
  rgbToHex(r, g, b) {
    const toHex = (n) => {
      const hex = Math.max(0, Math.min(255, Math.round(n))).toString(16);
      return hex.length === 1 ? '0' + hex : hex;
    };
    return toHex(r) + toHex(g) + toHex(b);
  },

  /**
   * Convert hex to RGB tuple
   */
  hexToRgb(hex) {
    hex = hex.replace(/^#/, '');
    if (hex.length !== 6) return null;
    
    return {
      r: parseInt(hex.substr(0, 2), 16),
      g: parseInt(hex.substr(2, 2), 16),
      b: parseInt(hex.substr(4, 2), 16)
    };
  },

  /**
   * Create a shareable theme from current URL or custom colors
   */
  shareCurrentTheme() {
    const theme = this.getThemeParam();
    const url = this.buildUrl({ theme });
    
    console.log('Current theme:', theme);
    console.log('Shareable URL:', url);
    
    return url;
  }
};

// Export for use in modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = window.TStorieThemes;
}
