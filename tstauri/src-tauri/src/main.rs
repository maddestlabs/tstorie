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
    let resource_path = app.path()
        .resource_dir()
        .map_err(|e| format!("Failed to get resource dir: {}", e))?;
    
    let file_path = resource_path.join(&filename);
    fs::read(&file_path)
        .map_err(|e| format!("Failed to read {}: {}", filename, e))
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

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .invoke_handler(tauri::generate_handler![
            load_markdown_content,
            get_bundled_wasm_path,
            get_bundled_wasm_file
        ])
        .setup(|app| {
            let window = app.get_webview_window("main").unwrap();
            
            // Clone window for the closure
            let window_clone = window.clone();
            
            // Handle file drop events using window events
            window.on_window_event(move |event| {
                if let tauri::WindowEvent::DragDrop(tauri::DragDropEvent::Drop {paths, position: _}) = event {
                    if let Some(path) = paths.first() {
                        if path.extension().and_then(|s| s.to_str()) == Some("md") {
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
