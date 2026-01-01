# AsyncTaskService Migration Guide

## Overview
AsyncTaskService consolidates ~40+ duplicate `Task { @MainActor in }` patterns into a unified, DRY service with consistent error handling, cancellation, retry logic, and debouncing.

---

## Migration Examples

### **1. Basic Task Execution**

**Before:**