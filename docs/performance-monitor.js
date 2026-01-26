/**
 * TStorie Performance Monitor
 * Tracks and reports performance metrics
 */

class PerformanceMonitor {
  constructor() {
    this.metrics = {};
    this.marks = new Map();
    this.startTime = performance.now();
  }
  
  /**
   * Mark a performance point
   */
  mark(name) {
    const time = performance.now() - this.startTime;
    this.marks.set(name, time);
    
    if (performance.mark) {
      performance.mark(name);
    }
    
    console.log(`[Perf] ${name}: ${time.toFixed(0)}ms`);
    return time;
  }
  
  /**
   * Measure time between two marks
   */
  measure(name, startMark, endMark) {
    const start = this.marks.get(startMark) || 0;
    const end = this.marks.get(endMark) || performance.now() - this.startTime;
    const duration = end - start;
    
    this.metrics[name] = duration;
    
    if (performance.measure) {
      try {
        performance.measure(name, startMark, endMark);
      } catch (e) {
        // Marks might not exist in Performance API
      }
    }
    
    console.log(`[Perf] ${name}: ${duration.toFixed(0)}ms`);
    return duration;
  }
  
  /**
   * Get time since start
   */
  elapsed() {
    return performance.now() - this.startTime;
  }
  
  /**
   * Get all metrics
   */
  getMetrics() {
    return {
      ...this.metrics,
      elapsed: this.elapsed(),
      marks: Object.fromEntries(this.marks)
    };
  }
  
  /**
   * Get Web Vitals
   */
  async getWebVitals() {
    const vitals = {};
    
    // First Contentful Paint
    try {
      const fcpEntry = performance.getEntriesByName('first-contentful-paint')[0];
      if (fcpEntry) {
        vitals.fcp = fcpEntry.startTime;
      }
    } catch (e) {}
    
    // Largest Contentful Paint
    if ('PerformanceObserver' in window) {
      try {
        const lcpObserver = new PerformanceObserver((list) => {
          const entries = list.getEntries();
          const lastEntry = entries[entries.length - 1];
          vitals.lcp = lastEntry.renderTime || lastEntry.loadTime;
        });
        lcpObserver.observe({ entryTypes: ['largest-contentful-paint'] });
      } catch (e) {}
    }
    
    // First Input Delay
    if ('PerformanceObserver' in window) {
      try {
        const fidObserver = new PerformanceObserver((list) => {
          const entries = list.getEntries();
          entries.forEach(entry => {
            vitals.fid = entry.processingStart - entry.startTime;
          });
        });
        fidObserver.observe({ entryTypes: ['first-input'] });
      } catch (e) {}
    }
    
    return vitals;
  }
  
  /**
   * Get resource timing
   */
  getResourceTiming() {
    if (!performance.getEntriesByType) return [];
    
    return performance.getEntriesByType('resource').map(entry => ({
      name: entry.name,
      size: entry.transferSize,
      duration: entry.duration,
      type: entry.initiatorType
    }));
  }
  
  /**
   * Report to analytics (stub)
   */
  report() {
    const metrics = this.getMetrics();
    console.log('[Perf] Metrics:', metrics);
    
    // TODO: Send to analytics service
    // if (window.gtag) {
    //   gtag('event', 'timing_complete', {
    //     name: 'load',
    //     value: metrics.elapsed,
    //     event_category: 'Performance'
    //   });
    // }
    
    return metrics;
  }
  
  /**
   * Create visual performance report
   */
  createReport() {
    const metrics = this.getMetrics();
    const resources = this.getResourceTiming();
    
    const report = {
      summary: {
        totalTime: metrics.elapsed?.toFixed(0) + 'ms',
        coreLoad: metrics.coreLoad?.toFixed(0) + 'ms',
        ttfLoad: metrics.ttfLoad?.toFixed(0) + 'ms',
        firstRender: metrics.firstRender?.toFixed(0) + 'ms'
      },
      resources: {
        total: resources.length,
        totalSize: resources.reduce((sum, r) => sum + (r.size || 0), 0),
        byType: this.groupResourcesByType(resources)
      },
      timeline: Array.from(this.marks.entries()).map(([name, time]) => ({
        name,
        time: time.toFixed(0) + 'ms'
      }))
    };
    
    return report;
  }
  
  groupResourcesByType(resources) {
    const grouped = {};
    resources.forEach(r => {
      if (!grouped[r.type]) {
        grouped[r.type] = { count: 0, size: 0 };
      }
      grouped[r.type].count++;
      grouped[r.type].size += r.size || 0;
    });
    return grouped;
  }
}

window.PerformanceMonitor = PerformanceMonitor;
