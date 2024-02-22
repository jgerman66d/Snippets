const { Storage } = require('@google-cloud/storage');
const axios = require('axios');
const fs = require('fs');
const path = require('path');

const ARTIFACTORY_URL = "your-artifactory-url"; // Replace with your Artifactory URL
const REPO_NAME = "patch";
const MIRROR_URL = "http://mirror.centos.org/centos/7/os/x86_64/Packages/";
const BUCKET_NAME = 'your-gcs-bucket-name'; // Replace with your GCS bucket name

// Instantiates a GCS client
const storage = new Storage();

// Function to get the latest version of a package
async function getLatestVersion(packageName) {
  try {
    const response = await axios.get(MIRROR_URL);
    const regex = new RegExp(`${packageName}-[0-9]+\\.[0-9]+\\.[0-9]+-[0-9]+\\.el7\\.(i686|x86_64)\\.rpm`, 'g');
    const matches = response.data.match(regex);
    if (!matches) {
      throw new Error(`No versions found for package ${packageName}`);
    }
    const latestVersion = matches.sort().pop(); // Simple sort, might need improvement for version sorting
    return latestVersion;
  } catch (error) {
    console.error(`Failed to fetch the latest version for ${packageName}: ${error}`);
    process.exit(1);
  }
}

// Function to upload a file to GCS
async function uploadFileToGCS(filePath, destFileName) {
  await storage.bucket(BUCKET_NAME).upload(filePath, {
    destination: destFileName,
  });
  console.log(`${filePath} uploaded to ${BUCKET_NAME} as ${destFileName}`);
}

// Function to download a file using axios and save it locally
async function downloadFile(fileUrl, outputPath) {
  const writer = fs.createWriteStream(outputPath);
  const response = await axios({
    method: 'get',
    url: fileUrl,
    responseType: 'stream',
  });

  response.data.pipe(writer);

  return new Promise((resolve, reject) => {
    writer.on('finish', resolve);
    writer.on('error', reject);
  });
}

// Function to download and upload a package
async function processPackage(packageName) {
  const latestVersion = await getLatestVersion(packageName);
  const packageUrl = `${MIRROR_URL}${latestVersion}`;
  const packageFile = path.basename(latestVersion);
  const outputPath = path.join('/tmp', packageFile); // Use /tmp for temporary storage

  console.log(`Downloading ${packageName} (latest version) from ${packageUrl}...`);
  await downloadFile(packageUrl, outputPath);

  console.log(`Uploading ${packageName} (latest version) to GCS bucket ${BUCKET_NAME}...`);
  await uploadFileToGCS(outputPath, packageFile);

  // Optionally, clean up the local file after upload
  fs.unlinkSync(outputPath);
}

// Main function to read package names from the input file and process each package
async function main() {
  const inputFilePath = process.argv[2];
  if (!inputFilePath) {
    console.log("Usage: node patch.js <package_list_file>");
    process.exit(1);
  }

  let packages;
  if (inputFilePath.endsWith('.json')) {
    const data = fs.readFileSync(inputFilePath);
    const json = JSON.parse(data);
    packages = json.packages;
  } else {
    const data = fs.readFileSync(inputFilePath, 'utf8');
    packages = data.split('\n').filter(Boolean);
  }

  for (const packageName of packages) {
    await processPackage(packageName);
  }
}

main().catch(error => console.error(error));
