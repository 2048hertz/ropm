#!/bin/bash

# ROPM (RObert Package Manager)

# This wrapper/package manager was written by Ayaan Eusufzai
# Starting date: January 6th, 2025
# Helper function to print usage instructions
print_usage() {
    echo "Usage: ropm-bash [-y] <command> <package>"
    echo "Commands:"
    echo "  find <package>        Search for a package in both repositories"
    echo "  install <package>     Install a package (choose between Containerized or Normal)"
    echo "  remove <package>      Remove a package (choose between Containerized or Normal)"
    echo "Options:"
    echo "  -y                    Automatic confirmation for operations"
}

find_containerized() {
    echo "Searching in Containerized repositories..."
    if ! command -v flatpak &> /dev/null; then
        echo "Error: Flatpak is not installed or configured properly."
        return 1
    fi

    # Perform the search with specified columns
    results=$(flatpak search --columns=application,name,description "$1" 2>/dev/null)
    if [[ -z "$results" ]]; then
        echo "No results found in Containerized repositories."
        return
    fi

    # Read the results line by line
    echo "$results" | while IFS= read -r line; do
        # Skip the header line
        if [[ $line == "Application ID Name Description" ]]; then
            continue
        fi

        # Extract fields using a reliable delimiter (e.g., tab)
        IFS=$'\t' read -r app_id app_name app_description <<< "$line"

        # Handle cases where description might be missing
        if [[ -z $app_description ]]; then
            app_description="No description available."
        fi

        # Print the formatted output
        echo "[Containerized] Name: $app_name, App ID: $app_id, Description: $app_description"
    done
}

# Function to search for DNF (normal) packages
find_normal() {
    echo "Searching in Normal repositories..."
    if ! command -v dnf &> /dev/null; then
        echo "Error: DNF is not installed or configured properly."
        return 1
    fi
    results=$(dnf search "$1" 2>/dev/null)
    if [[ -z "$results" ]]; then
        echo "No results found in Normal repositories."
    else
        echo "$results" | awk 'NR>1 {print "[Normal] "$0}'
    fi
}

# Function to install a Flatpak application
install_containerized() {
    echo "Searching for '$1' in Containerized repositories..."
    flatpak search "$1"
    echo "Please enter the App ID of the application you want to install, or type 0 to cancel:"
    read -p "App ID: " APP_ID
    if [[ "$APP_ID" == "0" ]]; then
        echo "Installation cancelled."
        return 0
    fi
    if [[ -z "$APP_ID" ]]; then
        echo "No App ID provided. Installation cancelled."
        return 1
    fi
    if [[ "$AUTO_CONFIRM" == "true" ]]; then
        flatpak install -y "$APP_ID"
    else
        flatpak install "$APP_ID"
    fi
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to install the Flatpak application."
        return 1
    fi
}

# Function to install a DNF package
install_normal() {
    if [[ "$AUTO_CONFIRM" == "true" ]]; then
        sudo dnf install -y "$1"
    else
        sudo dnf install "$1"
    fi
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to install the package via DNF."
        return 1
    fi
}

remove_containerized() {
    echo "Searching for '$1' in installed Containerized applications..."

    # Check if Flatpak is installed
    if ! command -v flatpak &> /dev/null; then
        echo "Error: Flatpak is not installed or configured properly."
        return 1
    fi

    # List installed apps and filter by the provided package name
    APP_ID=$(flatpak list --app --columns=application | grep -i "^$1$" || true)

    # If exact match is not found, attempt a case-insensitive search
    if [[ -z "$APP_ID" ]]; then
        APP_ID=$(flatpak list --app --columns=application | grep -i "$1" || true)
    fi

    # If still not found, inform the user and exit
    if [[ -z "$APP_ID" ]]; then
        echo "No matching Flatpak application found for '$1'."
        echo "Please ensure the application name is correct. You can list installed Flatpak applications using:"
        echo "  flatpak list --app"
        return 1
    fi

    # Confirm the application to be removed
    echo "The following Flatpak application will be removed: $APP_ID"
    if [[ "$AUTO_CONFIRM" != "true" ]]; then
        read -p "Do you want to proceed? (y/N): " CONFIRM
        case "$CONFIRM" in
            [Yy]* ) ;;
            * ) echo "Uninstallation cancelled."; return 0 ;;
        esac
    fi

    # Uninstall the application and its data
    if [[ "$AUTO_CONFIRM" == "true" ]]; then
        flatpak uninstall -y --delete-data "$APP_ID"
    else
        flatpak uninstall --delete-data "$APP_ID"
    fi

    # Check for uninstallation success
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to uninstall the Flatpak application."
        return 1
    else
        echo "Successfully uninstalled the Flatpak application: $APP_ID"
    fi

    # Optionally, remove unused runtimes to free up space
    if [[ "$AUTO_CONFIRM" == "true" ]]; then
        flatpak uninstall -y --unused
    else
        read -p "Do you want to remove unused Flatpak runtimes to free up space? (y/N): " CLEANUP
        case "$CLEANUP" in
            [Yy]* ) flatpak uninstall --unused ;;
            * ) echo "Unused runtimes were not removed." ;;
        esac
    fi
}


# Function to remove a DNF package
remove_normal() {
    if [[ "$AUTO_CONFIRM" == "true" ]]; then
        sudo dnf remove -y "$1"
    else
        sudo dnf remove "$1"
    fi
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to remove the package via DNF."
        return 1
    fi
}

# Parse flags
AUTO_CONFIRM=false
while getopts "y" opt; do
    case $opt in
        y) AUTO_CONFIRM=true ;;
        *) print_usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# Ensure command and package are provided
COMMAND="$1"
PACKAGE="$2"
if [[ -z "$COMMAND" || -z "$PACKAGE" ]]; then
    print_usage
    exit 1
fi

# Main command handling
case "$COMMAND" in
    find)
        find_containerized "$PACKAGE"
        find_normal "$PACKAGE"
        ;;
    install)
        echo "Do you want to install the application as Containerized (sandboxed) or Normal (system-wide)?"
        read -p "Enter C for Containerized or N for Normal: " CHOICE
        case "$CHOICE" in
            [Cc]*)
                install_containerized "$PACKAGE"
                ;;
            [Nn]*)
                echo "Attempting to install '$PACKAGE' via Normal repositories..."
                if dnf search "$PACKAGE" 2>/dev/null | grep -q "$PACKAGE"; then
                    install_normal "$PACKAGE"
                else
                    echo "'$PACKAGE' not found in Normal repositories."
                fi
                ;;
            *)
                echo "Invalid choice. Please select C for Containerized or N for Normal."
                ;;
        esac
        ;;
    remove)
        echo "Do you want to remove the application from Containerized (sandboxed) or Normal (system-wide)?"
        read -p "Enter C for Containerized or N for Normal: " CHOICE
        case "$CHOICE" in
            [Cc]*)
                remove_containerized "$PACKAGE"
                ;;
            [Nn]*)
                echo "Attempting to remove '$PACKAGE' via Normal repositories..."
                if dnf list installed "$PACKAGE" 2>/dev/null | grep -q "$PACKAGE"; then
                    remove_normal "$PACKAGE"
                else
                    echo "'$PACKAGE' is not installed via Normal repositories."
                fi
                ;;
            *)
                echo "Invalid choice. Please select C for Containerized or N for Normal."
                ;;
        esac
        ;;
    *)
        print_usage
        exit 1
        ;;
esac

