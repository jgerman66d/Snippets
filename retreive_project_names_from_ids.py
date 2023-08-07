import csv
import subprocess

def get_project_info(csv_file_path, output_file_path):
    # Read the input CSV
    with open(csv_file_path, 'r') as file:
        reader = csv.reader(file)
        # Skip the header row
        next(reader)
        
        # Extract project ID from the first row
        first_row = next(reader)
        project_path = first_row[0] # Assuming the project path is in the first column
        project_id = project_path.replace('projects/', '')

    # Run the gcloud command
    cmd = ["gcloud", "project", "describe", project_id]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise Exception(f"Failed to run gcloud command. Error: {result.stderr}")

    project_description = result.stdout

    # Write to the output CSV file
    with open(csv_file_path, 'r') as infile, open(output_file_path, 'w', newline='') as outfile:
        reader = csv.reader(infile)
        writer = csv.writer(outfile)
        
        # Write the header to the output
        header = next(reader)
        writer.writerow(header)
        
        # Write the project description as the second row
        writer.writerow([project_description])

        # Write the remaining rows
        for row in reader:
            writer.writerow(row)

    print("Output written to", output_file_path)

# Usage
csv_file_path = 'path_to_input_csv.csv'
output_file_path = 'path_to_output_csv.csv'
get_project_info(csv_file_path, output_file_path)

