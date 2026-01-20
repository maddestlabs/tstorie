// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::{Manager, Emitter};
use std::fs;
use std::path::PathBuf;

#[tauri::command]
fn load_markdown_content(path: String) -> Result<String, String> {
    fs::read_to_string(&path)
        .map_err(|e| format!("Failed to read file: {}", e))
}

#[tauri::command]
fn get_bundled_wasm_file(app: tauri::AppHandle, filename: String) -> Result<Vec<u8>, String> {
    // Try bundled resources first
    if let Ok(resource_path) = app.path().resource_dir() {
        let file_path = resource_path.join(&filename);
        if file_path.exists() {
            return fs::read(&file_path)
                .map_err(|e| format!("Failed to read {}: {}", filename, e));
        }
    }
    
    // Try current directory (portable builds)
    let cwd_path = std::env::current_dir()
        .ok()
        .map(|p| p.join(&filename));
    if let Some(file_path) = cwd_path {
        if file_path.exists() {
            return fs::read(&file_path)
                .map_err(|e| format!("Failed to read {}: {}", filename, e));
        }
    }
    
    Err(format!("{} not found in resources or current directory", filename))
}

#[tauri::command]
fn get_bundled_wasm_path(app: tauri::AppHandle) -> Result<String, String> {
    let resource_path = app.path()
        .resource_dir()
        .map_err(|e| format!("Failed to get resource dir: {}", e))?;
    
    // Convert to a clean path string, removing Windows extended-length prefix
    let path_str = resource_path.to_string_lossy().to_string();
    let clean_path = if path_str.starts_with(r"\\?\") {
        path_str.trim_start_matches(r"\\?\").to_string()
    } else {
        path_str
    };
    
    Ok(clean_path)
}

#[tauri::command]
fn load_bundled_welcome(app: tauri::AppHandle) -> Result<String, String> {
    // Try multiple locations in order of preference
    
    // 1. Try bundled resources directory (release builds with proper installers)
    if let Ok(resource_path) = app.path().resource_dir() {
        let file_path = resource_path.join("index.md");
        eprintln!("Checking bundled resources: {:?}", file_path);
        if file_path.exists() {
            eprintln!("✓ Found in bundled resources");
            return fs::read_to_string(&file_path)
                .map_err(|e| format!("Failed to read welcome screen: {}", e));
        } else {
            eprintln!("  Not found in bundled resources");
        }
    }
    
    // 2. Try executable directory (portable builds - most common)
    if let Ok(exe_path) = std::env::current_exe() {
        if let Some(exe_dir) = exe_path.parent() {
            let file_path = exe_dir.join("index.md");
            eprintln!("Checking executable directory: {:?}", file_path);
            if file_path.exists() {
                eprintln!("✓ Found in executable directory");
                return fs::read_to_string(&file_path)
                    .map_err(|e| format!("Failed to read welcome screen: {}", e));
            } else {
                eprintln!("  Not found in executable directory");
            }
        }
    }
    
    // 3. Try current working directory
    if let Ok(cwd) = std::env::current_dir() {
        let file_path = cwd.join("index.md");
        eprintln!("Checking current directory: {:?}", file_path);
        if file_path.exists() {
            eprintln!("✓ Found in current directory");
            return fs::read_to_string(&file_path)
                .map_err(|e| format!("Failed to read welcome screen: {}", e));
        } else {
            eprintln!("  Not found in current directory");
        }
    }
    
    // 4. Try dev mode location (for development)
    if let Ok(resource_path) = app.path().resource_dir() {
        let dev_path = resource_path.parent()
            .and_then(|p| p.parent())
            .map(|p| p.join("dist-tstauri").join("index.md"));
        
        if let Some(file_path) = dev_path {
            eprintln!("Checking dev location: {:?}", file_path);
            if file_path.exists() {
                eprintln!("✓ Found in dev location");
                return fs::read_to_string(&file_path)
                    .map_err(|e| format!("Failed to read welcome screen: {}", e));
            } else {
                eprintln!("  Not found in dev location");
            }
        }
    }
    
    // Not found anywhere - provide helpful error
    Err("Welcome screen (index.md) not found. Please ensure it's bundled in the app or in the same folder as the executable.".to_string())
}

#[tauri::command]
fn load_bundled_shader(app: tauri::AppHandle, shader_name: String) -> Result<String, String> {
    let shader_file = format!("{}.js", shader_name);
    
    // Try bundled resources first
    if let Ok(resource_path) = app.path().resource_dir() {
        let file_path = resource_path.join("shaders").join(&shader_file);
        if file_path.exists() {
            return fs::read_to_string(&file_path)
                .map_err(|e| format!("Failed to read shader '{}': {}", shader_name, e));
        }
    }
    
    // Try current directory (portable builds)
    let cwd_path = std::env::current_dir()
        .ok()
        .map(|p| p.join("shaders").join(&shader_file));
    if let Some(file_path) = cwd_path {
        if file_path.exists() {
            return fs::read_to_string(&file_path)
                .map_err(|e| format!("Failed to read shader '{}': {}", shader_name, e));
        }
    }
    
    Err(format!("Shader '{}' not found in resources or current directory", shader_name))
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .invoke_handler(tauri::generate_handler![
            load_markdown_content,
            get_bundled_wasm_path,
            get_bundled_wasm_file,
            load_bundled_welcome,
            load_bundled_shader
        ])
        .setup(|app| {
            let window = app.get_webview_window("main").unwrap();
            
            // Check for command-line arguments (file dropped on exe)
            let args: Vec<String> = std::env::args().collect();
            if args.len() > 1 {
                // Skip first arg (exe path), check remaining for .md or .png files
                for arg in &args[1..] {
                    let path = std::path::Path::new(arg);
                    if path.exists() {
                        let ext = path.extension().and_then(|s| s.to_str());
                        if ext == Some("md") || ext == Some("png") {
                            // Clone window for async emit
                            let window_for_emit = window.clone();
                            let file_path = arg.clone();
                            
                            // Emit after a short delay to ensure frontend is ready
                            std::thread::spawn(move || {
                                std::thread::sleep(std::time::Duration::from_millis(500));
                                let _ = window_for_emit.emit("cli-file-arg", file_path);
                            });
                            
                            break; // Only load first valid file
                        }
                    }
                }
            }
            
            // Clone window for the closure
            let window_clone = window.clone();
            
            // Handle file drop events using window events
            window.on_window_event(move |event| {
                if let tauri::WindowEvent::DragDrop(tauri::DragDropEvent::Drop {paths, position: _}) = event {
                    if let Some(path) = paths.first() {
                        let ext = path.extension().and_then(|s| s.to_str());
                        if ext == Some("md") || ext == Some("png") {
                            // Send the file path to the frontend
                            let _ = window_clone.emit("file-dropped", path.to_string_lossy().to_string());
                        }
                    }
                }
            });
            
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
