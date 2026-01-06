
#!/bin/bash
# Step 1: Replace /storage/gitRepos with /app
sudo sed -i 's|/storage/gitRepos|/app|g' setup.sh
# Step 2: Replace any remaining /storage/ with /app
sudo sed -i 's|/storage/|/app/|g' setup.sh
