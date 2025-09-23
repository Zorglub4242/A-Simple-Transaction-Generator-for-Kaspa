@echo off
set PROTOC=%cd%\protoc_install\bin\protoc.exe
echo Using PROTOC: %PROTOC%
cd rusty-kaspa
cargo build --release --bin Tx_gen
cd ..
echo.
echo Build complete! To run:
echo   cd rusty-kaspa
echo   cargo run --release --bin Tx_gen