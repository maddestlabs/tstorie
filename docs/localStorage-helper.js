/**
 * TStorie localStorage Helper
 * 
 * Simple utility functions for saving and loading TStorie content
 * from browser localStorage.
 * 
 * Usage:
 *   // Save content
 *   TStorie.saveLocal('my-draft', markdownContent);
 *   
 *   // Load content
 *   const content = TStorie.loadLocal('my-draft');
 *   
 *   // List all saved items
 *   const items = TStorie.listLocal();
 *   
 *   // Delete content
 *   TStorie.deleteLocal('my-draft');
 *   
 *   // Load in browser
 *   window.location.href = '?content=browser:my-draft';
 */

window.TStorie = window.TStorie || {};

// Key prefix for TStorie items in localStorage
const TSTORIE_PREFIX = 'tstorie_';

/**
 * Save markdown content to localStorage
 * @param {string} key - Unique identifier for the content
 * @param {string} content - Markdown content to save
 * @returns {boolean} - True if saved successfully
 */
TStorie.saveLocal = function(key, content) {
    try {
        const storageKey = TSTORIE_PREFIX + key;
        localStorage.setItem(storageKey, content);
        console.log('Saved to localStorage:', storageKey, '(' + content.length + ' bytes)');
        return true;
    } catch (e) {
        console.error('Error saving to localStorage:', e);
        return false;
    }
};

/**
 * Load markdown content from localStorage
 * @param {string} key - Unique identifier for the content
 * @returns {string|null} - The content or null if not found
 */
TStorie.loadLocal = function(key) {
    try {
        const storageKey = TSTORIE_PREFIX + key;
        const content = localStorage.getItem(storageKey);
        if (content) {
            console.log('Loaded from localStorage:', storageKey, '(' + content.length + ' bytes)');
        } else {
            console.warn('No content found for:', storageKey);
        }
        return content;
    } catch (e) {
        console.error('Error loading from localStorage:', e);
        return null;
    }
};

/**
 * Delete content from localStorage
 * @param {string} key - Unique identifier for the content
 * @returns {boolean} - True if deleted successfully
 */
TStorie.deleteLocal = function(key) {
    try {
        const storageKey = TSTORIE_PREFIX + key;
        localStorage.removeItem(storageKey);
        console.log('Deleted from localStorage:', storageKey);
        return true;
    } catch (e) {
        console.error('Error deleting from localStorage:', e);
        return false;
    }
};

/**
 * List all TStorie items in localStorage
 * @returns {Array<{key: string, size: number, preview: string}>}
 */
TStorie.listLocal = function() {
    const items = [];
    try {
        for (let i = 0; i < localStorage.length; i++) {
            const fullKey = localStorage.key(i);
            if (fullKey && fullKey.startsWith(TSTORIE_PREFIX)) {
                const key = fullKey.substring(TSTORIE_PREFIX.length);
                const content = localStorage.getItem(fullKey);
                if (content) {
                    items.push({
                        key: key,
                        size: content.length,
                        preview: content.substring(0, 100) + (content.length > 100 ? '...' : '')
                    });
                }
            }
        }
    } catch (e) {
        console.error('Error listing localStorage items:', e);
    }
    return items;
};

/**
 * Get storage usage information
 * @returns {object} - Storage usage stats
 */
TStorie.storageInfo = function() {
    let totalSize = 0;
    let itemCount = 0;
    
    try {
        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && key.startsWith(TSTORIE_PREFIX)) {
                const item = localStorage.getItem(key);
                if (item) {
                    totalSize += item.length;
                    itemCount++;
                }
            }
        }
    } catch (e) {
        console.error('Error getting storage info:', e);
    }
    
    return {
        items: itemCount,
        bytes: totalSize,
        kilobytes: (totalSize / 1024).toFixed(2),
        megabytes: (totalSize / 1024 / 1024).toFixed(2)
    };
};

console.log('TStorie localStorage helper loaded. Use TStorie.saveLocal(), TStorie.loadLocal(), etc.');
