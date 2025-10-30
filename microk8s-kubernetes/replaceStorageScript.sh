
#!/bin/bash
# Step 1: Replace /storage/gitRepos with /app
sudo sed -i 's|/storage/gitRepos|/app|g' /path/to/your/file
# Step 2: Replace any remaining /storage/ with /app
sudo sed -i 's|/storage/|/app/|g' /path/to/your/file