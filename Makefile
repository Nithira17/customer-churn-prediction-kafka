.PHONY: all clean install setup-dirs train-pipeline data-pipeline clean-kill help

# Default Python interpreter
PYTHON = python
VENV = .venv\Scripts\activate
MLFLOW_PORT ?= 5001

# Set PYTHONPATH to include src and utils directories
PYTHONPATH = $(shell cd)\\src;$(shell cd)\\utils

# Default target
all: help

# Help target
help:
	@echo Available targets:
	@echo.
	@echo Setup Commands:
	@echo   make install             - Install project dependencies and set up environment
	@echo   make setup-dirs          - Create necessary directories for pipelines
	@echo   make clean               - Clean up artifacts
	@echo.
	@echo ML Pipeline Commands:
	@echo   make data-pipeline       - Run the data pipeline
	@echo   make train-pipeline      - Run the training pipeline (PySpark MLlib)
	@echo   make batch-inference     - Run the batch inference pipeline
	@echo.
	@echo MLflow Commands:
	@echo   make mlflow-ui           - Launch MLflow UI (port $(MLFLOW_PORT))
	@echo   make stop-all            - Stop all MLflow servers
	@echo.
	@echo Kafka Streaming Commands:
	@echo   make kafka-install       - Install Kafka natively (first time)
	@echo   make kafka-validate      - Validate Kafka installation
	@echo   make kafka-format        - Format Kafka storage (first time)
	@echo   make kafka-start         - Start native Kafka broker
	@echo   make kafka-topics        - Create churn prediction topic
	@echo   make kafka-cleanup-topics - Remove unused topics
	@echo.
	@echo Data Production Commands:
	@echo   make kafka-producer-stream - Stream events (1/sec for 5 mins)
	@echo   make kafka-producer-batch  - Batch produce events
	@echo.
	@echo ML Processing Commands:
	@echo   make kafka-consumer        - Batch ML consumer (process all messages)
	@echo   make kafka-consumer-continuous - Continuous ML consumer (real-time)
	@echo.
	@echo Monitoring Commands:
	@echo   make kafka-check         - Check broker status
	@echo   make kafka-monitor       - Monitor cluster health
	@echo   make kafka-help          - Show all Kafka commands
	@echo.
	@echo Airflow Orchestration Commands:
	@echo   make sync-dags-to-wsl    - Sync DAG files from Windows to WSL2 Airflow
	@echo   make airflow-start-wsl   - Start Airflow in WSL2
	@echo   make airflow-status      - Check if Airflow is running
	@echo   make airflow-stop-wsl    - Stop Airflow in WSL2
	@echo   make airflow-deploy      - Deploy DAGs to WSL2 Airflow
	@echo   make clean-kill          - Kill all processes and clean logs/data
	@echo.
	@echo Quick Start (Batch Processing):
	@echo   1. make install && make setup-dirs
	@echo   2. make kafka-start-bg && make kafka-topics
	@echo   3. make kafka-producer-batch
	@echo   4. make kafka-consumer

# ========================================================================================
# SETUP AND ENVIRONMENT COMMANDS
# ========================================================================================

# Install project dependencies and set up environment
install:
	@echo Installing project dependencies and setting up environment...
	@echo Creating virtual environment...
	$(PYTHON) -m venv .venv
	@echo Activating virtual environment and installing dependencies...
	.venv\Scripts\activate && python.exe -m pip install --upgrade pip
	.venv\Scripts\activate && pip install -r requirements.txt
	@echo Installation completed successfully!
	@echo To activate the virtual environment, run: .venv\Scripts\activate

# Create necessary directories
setup-dirs:
	@echo Creating necessary directories...
	@if not exist artifacts\data mkdir artifacts\data
	@if not exist artifacts\models mkdir artifacts\models
	@if not exist artifacts\encode mkdir artifacts\encode
	@if not exist artifacts\mlflow_run_artifacts mkdir artifacts\mlflow_run_artifacts
	@if not exist artifacts\mlflow_training_artifacts mkdir artifacts\mlflow_training_artifacts
	@if not exist artifacts\inference_batches mkdir artifacts\inference_batches
	@if not exist data\processed mkdir data\processed
	@if not exist data\raw mkdir data\raw
	@if not exist runtime\kafka-logs mkdir runtime\kafka-logs
	@if not exist runtime\pids mkdir runtime\pids
	@echo Directories created successfully!

# Clean up
clean:
	@echo Cleaning up artifacts...
	@if exist artifacts rmdir /s /q artifacts
	@if exist mlruns rmdir /s /q mlruns
	@echo Cleanup completed!

# ========================================================================================
# ML PIPELINE COMMANDS (PySpark MLlib Only)
# ========================================================================================

# Run data pipeline
data-pipeline: setup-dirs
	@echo Running data pipeline...
	@echo Setting PYTHONPATH to include src and utils directories...
	.venv\Scripts\activate && set PYTHONPATH=$(PYTHONPATH) && $(PYTHON) pipelines/data_pipeline.py
	@echo Data pipeline completed successfully!

# Run training pipeline (PySpark MLlib)
train-pipeline: setup-dirs
	@echo Running PySpark MLlib training pipeline...
	@echo Setting PYTHONPATH to include src and utils directories...
	.venv\Scripts\activate && set PYTHONPATH=$(PYTHONPATH) && $(PYTHON) pipelines/training_pipeline.py
	@echo Training pipeline completed successfully!

# Run batch inference pipeline
batch-inference: setup-dirs
	@echo Running batch inference pipeline...
	@echo Setting PYTHONPATH to include src and utils directories...
	.venv\Scripts\activate && set PYTHONPATH=$(PYTHONPATH) && $(PYTHON) pipelines/batch_inference_pipeline.py
	@echo Batch inference completed successfully!

# Comprehensive cleanup and kill command
clean-kill:
	@echo Comprehensive cleanup and kill operation...
	@echo ==========================================
	@echo WARNING: This will kill all processes and remove logs/data (NOT code)
	@set /p confirm="Continue? (y/N): "
	@if /i not "%confirm%"=="y" exit /b 1
	@echo.
	@echo Killing all processes...
	@taskkill /F /IM kafka.exe 2>nul || echo No Kafka processes found
	@taskkill /F /IM java.exe 2>nul || echo No Java processes found
	@taskkill /F /IM python.exe /FI "WINDOWTITLE eq *mlflow*" 2>nul || echo No MLflow processes found
	@taskkill /F /IM python.exe /FI "WINDOWTITLE eq *spark*" 2>nul || echo No Spark processes found
	@echo.
	@echo Removing logs and data directories...
	@if exist runtime\kafka-logs rmdir /s /q runtime\kafka-logs
	@if exist runtime\pids rmdir /s /q runtime\pids
	@if exist runtime\kafka.log del /q runtime\kafka.log
	@if exist mlruns rmdir /s /q mlruns
	@if exist artifacts\mlflow_run_artifacts rmdir /s /q artifacts\mlflow_run_artifacts
	@if exist artifacts\mlflow_training_artifacts rmdir /s /q artifacts\mlflow_training_artifacts
	@if exist artifacts\data\streaming_checkpoints rmdir /s /q artifacts\data\streaming_checkpoints
	@echo.
	@echo Freeing up ports...
	@for /f "tokens=5" %%a in ('netstat -ano ^| findstr :5000') do taskkill /PID %%a /F >nul 2>&1
	@for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8080') do taskkill /PID %%a /F >nul 2>&1
	@for /f "tokens=5" %%a in ('netstat -ano ^| findstr :9092') do taskkill /PID %%a /F >nul 2>&1
	@echo.
	@echo Cleanup completed successfully!
	@echo Ready for fresh start with: make setup-dirs

# ========================================================================================
# MLFLOW COMMANDS
# ========================================================================================

mlflow-ui:
	@echo Launching MLflow UI...
	@echo MLflow UI will be available at: http://localhost:$(MLFLOW_PORT)
	@echo Press Ctrl+C to stop the server
	.venv\Scripts\activate && mlflow ui --host 0.0.0.0 --port $(MLFLOW_PORT)

# Stop all running MLflow servers
stop-all:
	@echo Stopping all MLflow servers on port $(MLFLOW_PORT)...
	@for /f "tokens=5" %%a in ('netstat -ano ^| findstr :$(MLFLOW_PORT)') do taskkill /PID %%a /F >nul 2>&1
	@echo All MLflow servers on port $(MLFLOW_PORT) have been stopped!

# ========================================================================================
# NATIVE KAFKA STREAMING COMMANDS
# ========================================================================================

# Configuration
KAFKA_CONF = kafka\server.properties
KAFKA_LOG_DIR = runtime\kafka-logs
PID_DIR = runtime\pids

kafka-format:
	@echo Formatting native Kafka storage (KRaft mode)...
	@if not defined KAFKA_HOME (echo ERROR: KAFKA_HOME not set. Please install Kafka natively and set KAFKA_HOME && echo Installation guide: README_KAFKA.md && exit /b 1)
	@echo Creating runtime directories...
	@if not exist runtime\kafka-logs mkdir runtime\kafka-logs
	@if not exist runtime\pids mkdir runtime\pids
	@echo Generating cluster UUID...
	@for /f %%i in ('%KAFKA_HOME%\bin\windows\kafka-storage.bat random-uuid') do set CLUSTER_ID=%%i
	@echo Using Cluster ID: %CLUSTER_ID%
	@%KAFKA_HOME%\bin\windows\kafka-storage.bat format -t %CLUSTER_ID% -c "$(KAFKA_CONF)"
	@echo Native Kafka storage formatted successfully

kafka-start-bg:
	@echo Starting native Kafka broker in background...
	@if not defined KAFKA_HOME (echo ERROR: KAFKA_HOME not set && exit /b 1)
	@if not exist $(PID_DIR) mkdir $(PID_DIR)
	@start /B "" %KAFKA_HOME%\bin\windows\kafka-server-start.bat "$(KAFKA_CONF)" > runtime\kafka.log 2>&1
	@echo Kafka broker started in background
	@echo Logs: runtime\kafka.log

kafka-stop:
	@echo Stopping native Kafka broker...
	@if not defined KAFKA_HOME (echo ERROR: KAFKA_HOME not set && exit /b 1)
	@%KAFKA_HOME%\bin\windows\kafka-server-stop.bat
	@taskkill /F /IM java.exe 2>nul || echo No Kafka processes found
	@echo Kafka broker stopped

kafka-topics:
	@echo Creating churn prediction topics on native broker...
	@kafka-topics.bat --bootstrap-server localhost:9092 --list >nul 2>&1 || (echo ERROR: Cannot connect to native Kafka broker at localhost:9092 && echo Please start broker with 'make kafka-start-bg' && exit /b 1)
	@echo Creating churn_predictions topic...
	@kafka-topics.bat --bootstrap-server localhost:9092 --create --topic churn_predictions --partitions 1 --replication-factor 1 --if-not-exists
	@echo Creating churn_predictions_scored topic...
	@kafka-topics.bat --bootstrap-server localhost:9092 --create --topic churn_predictions_scored --partitions 1 --replication-factor 1 --if-not-exists
	@echo Churn predictions topics created successfully
	@echo Current topics on native broker:
	@kafka-topics.bat --bootstrap-server localhost:9092 --list

kafka-producer-stream:
	@echo Starting Kafka streaming producer (real data sampling)...
	@kafka-topics.bat --bootstrap-server localhost:9092 --list >nul 2>&1 || (echo ERROR: Cannot connect to native Kafka broker && echo Please start broker with 'make kafka-start-bg' && exit /b 1)
	@echo Streaming real customer events to localhost:9092 (1 event/sec for 5 mins)
	.venv\Scripts\activate && python pipelines/kafka_producer.py --mode streaming --rate 1 --duration 300

kafka-producer-batch:
	@echo Starting Kafka batch producer (real data sampling)...
	@kafka-topics.bat --bootstrap-server localhost:9092 --list >nul 2>&1 || (echo ERROR: Cannot connect to native Kafka broker && echo Please start broker with 'make kafka-start-bg' && exit /b 1)
	@echo Batch processing 100 real customer events to localhost:9092
	.venv\Scripts\activate && python pipelines/kafka_producer.py --mode batch --num-events 100

kafka-consumer:
	@echo Starting Kafka batch consumer with ML predictions...
	@kafka-topics.bat --bootstrap-server localhost:9092 --list >nul 2>&1 || (echo ERROR: Cannot connect to native Kafka broker && echo Please start broker with 'make kafka-start-bg' && exit /b 1)
	@echo Processing messages in batches with ML predictions
	.venv\Scripts\activate && python pipelines/kafka_batch_consumer.py

kafka-consumer-continuous:
	@echo Starting continuous Kafka consumer monitoring...
	@echo Monitoring for NEW messages (real-time ML processing)
	@echo Press Ctrl+C to stop monitoring
	.venv\Scripts\activate && python pipelines/kafka_batch_consumer.py --continuous --poll-interval 5

kafka-check:
	@echo Checking native Kafka broker status...
	@kafka-topics.bat --bootstrap-server localhost:9092 --list >nul 2>&1 && (echo Native Kafka broker is running at localhost:9092 && echo Available topics: && kafka-topics.bat --bootstrap-server localhost:9092 --list) || (echo ERROR: Cannot connect to native Kafka broker at localhost:9092 && echo Please start with 'make kafka-start-bg')

kafka-sample-scored:
	@echo Analyzing churn prediction results...
	@kafka-topics.bat --bootstrap-server localhost:9092 --list | findstr churn_predictions_scored >nul && (.venv\Scripts\activate && python scripts/kafka_analytics.py) || echo ERROR: churn_predictions_scored topic not found. Run 'make kafka-topics' first.

kafka-cleanup-topics:
	@echo Cleaning up unused Kafka topics...
	@kafka-topics.bat --bootstrap-server localhost:9092 --list >nul 2>&1 || (echo ERROR: Cannot connect to native Kafka broker && echo Please start broker with 'make kafka-start-bg' && exit /b 1)
	@echo Removing unused topics (keeping only churn_predictions)...
	@for %%t in (customer_events model_updates data_quality_alerts) do @(kafka-topics.bat --bootstrap-server localhost:9092 --list | findstr %%t >nul && (echo Deleting topic: %%t && kafka-topics.bat --bootstrap-server localhost:9092 --delete --topic %%t) || echo Topic %%t not found (already clean))
	@echo Topic cleanup completed
	@echo Remaining topics:
	@kafka-topics.bat --bootstrap-server localhost:9092 --list

kafka-flush-messages:
	@echo Flushing all messages from Kafka topics...
	@kafka-topics.bat --bootstrap-server localhost:9092 --list >nul 2>&1 || (echo ERROR: Cannot connect to native Kafka broker && echo Please start broker with 'make kafka-start-bg' && exit /b 1)
	@echo Deleting and recreating topics to flush all messages...
	@kafka-topics.bat --bootstrap-server localhost:9092 --delete --topic churn_predictions 2>nul || echo Topic churn_predictions not found
	@kafka-topics.bat --bootstrap-server localhost:9092 --delete --topic churn_predictions_scored 2>nul || echo Topic churn_predictions_scored not found
	@timeout /t 2 /nobreak >nul
	@echo Creating churn_predictions topic...
	@kafka-topics.bat --bootstrap-server localhost:9092 --create --topic churn_predictions --partitions 1 --replication-factor 1
	@echo Creating churn_predictions_scored topic...
	@kafka-topics.bat --bootstrap-server localhost:9092 --create --topic churn_predictions_scored --partitions 1 --replication-factor 1
	@echo All messages flushed - topics are now empty
	@echo Current topics:
	@kafka-topics.bat --bootstrap-server localhost:9092 --list

kafka-reset:
	@echo Resetting Kafka data (destructive operation)...
	@set /p confirm="WARNING: This will delete all Kafka data. Continue? (y/N): "
	@if /i not "%confirm%"=="y" exit /b 1
	@echo Stopping all Kafka processes...
	@taskkill /F /IM java.exe 2>nul || echo No Kafka processes found
	@timeout /t 2 /nobreak >nul
	@echo Force killing port users...
	@for /f "tokens=5" %%a in ('netstat -ano ^| findstr :9092') do taskkill /PID %%a /F >nul 2>&1
	@for /f "tokens=5" %%a in ('netstat -ano ^| findstr :9093') do taskkill /PID %%a /F >nul 2>&1
	@timeout /t 1 /nobreak >nul
	@echo Removing Kafka data directory...
	@if exist $(KAFKA_LOG_DIR) rmdir /s /q $(KAFKA_LOG_DIR)
	@echo Removing PID files...
	@if exist $(PID_DIR)\kafka.pid del /q $(PID_DIR)\kafka.pid
	@echo Kafka reset completed. Run 'make kafka-format' to reinitialize

kafka-help:
	@echo Native Kafka Commands Help
	@echo ==================================================
	@echo Installation Commands:
	@echo   kafka-install    - Install Kafka natively (first time)
	@echo   kafka-validate   - Validate installation
	@echo.
	@echo Setup Commands:
	@echo   kafka-format     - Format Kafka storage (first time)
	@echo   kafka-start-bg   - Start broker in background
	@echo   kafka-stop       - Stop native Kafka broker
	@echo   kafka-topics     - Create churn prediction topic
	@echo   kafka-cleanup-topics - Remove unused topics
	@echo.
	@echo Data Commands:
	@echo   kafka-producer-stream  - Start streaming producer (real data)
	@echo   kafka-producer-batch   - Start batch producer (real data)
	@echo   kafka-consumer         - Start batch ML consumer
	@echo   kafka-consumer-continuous - Start continuous ML consumer
	@echo.
	@echo Monitoring Commands:
	@echo   kafka-check      - Check broker status
	@echo   kafka-monitor    - Monitor cluster health
	@echo   kafka-sample-scored - Show prediction analytics and statistics
	@echo.
	@echo Utility Commands:
	@echo   kafka-reset      - Reset all Kafka data
	@echo   kafka-help       - Show this help
	@echo.
	@echo For detailed setup: README_KAFKA.md

# ========================================================================================
# APACHE AIRFLOW ORCHESTRATION COMMANDS (WSL2)
# ========================================================================================

# Sync DAGs from Windows to WSL2
sync-dags-to-wsl:
	@echo Syncing DAGs from Windows to WSL2...
	@wsl -d Ubuntu mkdir -p ~/airflow-class/.airflow/dags/
	@if exist dags for %%f in (dags\*.py) do wsl -d Ubuntu cp "/mnt/c/Users/hewaj/Desktop/Zuu Crew/Customer Churn Prediction - Kafka/dags/%%~nxf" "~/airflow-class/.airflow/dags/"
	@echo DAGs synced successfully!
	@echo Access Airflow UI at: http://localhost:8080

# Start Airflow in WSL2 (opens new terminal)
airflow-start-wsl:
	@echo Starting Airflow in WSL2...
	@echo This will open a new WSL2 terminal window
	wsl -d Ubuntu -e bash -c "cd ~/airflow-class && source .venv/bin/activate && ./start_airflow.sh"

# Check if Airflow is running
airflow-status:
	@echo Checking Airflow status...
	@curl -s http://localhost:8080/health || echo Airflow is not running
	@echo.
	@echo If running, access at: http://localhost:8080

# Stop Airflow (kills WSL2 processes)
airflow-stop-wsl:
	@echo Stopping Airflow in WSL2...
	@wsl -d Ubuntu pkill -f airflow || echo No Airflow processes found
	@echo Airflow stopped.

# Complete Airflow workflow
airflow-deploy:
	@echo Deploying to Airflow...
	@$(MAKE) sync-dags-to-wsl
	@echo DAGs deployed! Start Airflow with: make airflow-start-wsl
	@echo Or manually run in WSL2: cd ~/airflow-class && ./start_airflow.sh