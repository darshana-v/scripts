# ubuntu-setup

My ubuntu setup for coding documented here so I don't have to research the same resources again and because my vm runs out of space so often that I am tired of visiting the same tutorials.

The documentation is a bit leaned towards using ubuntu on a virtual machine.

- Update software
  - `sudo apt-get update && sudo apt update && sudo apt-get upgrade -y`
  - Uninstall unnecessary apps - Amazon, gaming etc from Ubuntu Software Centre
- Update and Upgrade Guest OS, Autoclean
  - `sudo apt -y dist-upgrade && sudo apt -y autoremove && sudo apt autoclean`
- Change dock settings to minimize on click
- Enable Shared clipboard, Drag and Drop to bidirectional
- Enable file transfer and sharing folders: vbox->choose machine->shared folders->add a new one->check 'yes' for Auto-mount
  - to access shared folders and location, add the user in vboxsf group: `sudo adduser <username> vboxsf`
  - verify: `id <username>`
- *Optional:* Change the icons size, taskbar location, background image
- *Optional:* Enable 3d acceleration
- Change settings (org.gnome.dektop.interface) to show remaining battery percentage
- Install chrome
  - `sudo apt install wget` (if not installed, do it)
  - `wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo dpkg -i google-chrome-stable_current_amd64.deb`
  - To open google chrome browser via terminal: `google-chrome`
- Enable firewall: `sudo ufw enable`
- git, node, npm and other development essentials
  - `sudo apt install git`
  - `git config --global user.email "<email_id>"`
  - `git config --global user.name "<name>"`
  - `sudo apt install nodejs && nodejs -v`
  - `sudo apt install npm && npm -v` or install nvm and other relevant node versions
  - installation through nvm: `wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash`, `command -v nvm`, `nvm install node`, `nvm install <version-number>` to reinstall a specific nodejs version, set the version as default using `nvm use <version no>`, check list of versions using `nvm ls-remote`
  - nodemon: `npm i -g nodemon`
  - vscode: `sudo snap install --classic code`
  - postman: `sudo snap install postman`
  - vlc: `sudo snap install vlc`
  - *Optional*: vim, make, curl: `sudo apt install vim make curl`, java
  - ngrok setup following documentation
  - MongoDB setup following documentation
- Improve battery performance: `sudo apt-get install tlp tlp-rdw && sudo systemctl enable tlp`
- To enlarge virtual machine disk space: check https://www.howtogeek.com/124622/how-to-enlarge-a-virtual-machines-disk-in-virtualbox-or-vmware/
- Important commands for system cleanup:
  - clean partial packages: `sudo apt-get autoclean`
  - remove unused dependencies: `sudo apt-get autoremove`
  - auto cleanup apt-cache: `sudo apt-get clean`
- Take a snapshot of the system state after all necessary installations
