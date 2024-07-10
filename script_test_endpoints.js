#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const axios = require('axios');
const { ApiPromise, WsProvider } = require('@polkadot/api');

// Directory containing the configuration files
const CONF_DIR = '/opt/haproxy-3.0.2/etc/conf/';
// Path to the local services_rpc.json file
const LOCAL_SERVICES_RPC = path.join(__dirname, 'services_rpc.json');
// URL of the services_rpc.json file
const SERVICES_RPC_URL = 'https://raw.githubusercontent.com/ibp-network/config/main/services_rpc.json';

// Delete the local services_rpc.json file if it exists
if (fs.existsSync(LOCAL_SERVICES_RPC)) {
    fs.unlinkSync(LOCAL_SERVICES_RPC);
}

// Relay chains
const relayChains = ['kusama', 'paseo', 'polkadot', 'westend'];

// Function to read and parse the configuration files
const readConfigFiles = (dir) => {
    return fs.readdirSync(dir).filter(file => file.endsWith('.cfg') && relayChains.some(chain => file.toLowerCase().includes(chain)));
};

// Function to extract server addresses from the configuration file
const extractServerAddresses = (filePath) => {
    const fileContent = fs.readFileSync(filePath, 'utf-8');
    const serverLines = fileContent.split('\n').filter(line => line.trim().startsWith('server') && !line.includes('wsp2p'));
    return serverLines.map(line => {
        const parts = line.split(/\s+/);
        const address = parts[3]; // the 4th part is the address
        const [ip, port] = address.split(':');
        return { ip, port };
    });
};

// Function to connect to the server and get the chain name
const getChainName = async (wsUrl) => {
    const originalConsoleError = console.error;
    const originalConsoleLog = console.log;
    const originalConsoleWarn = console.warn;
    const originalConsoleInfo = console.info;

    // Suppress console output
    console.error = () => {};
    console.log = () => {};
    console.warn = () => {};
    console.info = () => {};

    const provider = new WsProvider(wsUrl);
    const api = await ApiPromise.create({ provider });

    const chain = await api.rpc.system.chain();
    await api.disconnect();

    // Restore console output
    console.error = originalConsoleError;
    console.log = originalConsoleLog;
    console.warn = originalConsoleWarn;
    console.info = originalConsoleInfo;

    return chain.toString();
};

// Function to download and parse the services_rpc.json file
const downloadServicesRpc = async (url) => {
    const response = await axios.get(url);
    return response.data;
};

// Normalize keys to lowercase
const normalizeKeys = (obj) => {
    return Object.keys(obj).reduce((acc, key) => {
        acc[key.toLowerCase()] = obj[key];
        return acc;
    }, {});
};

// Main function to process the files
const processFiles = async () => {
    const servicesRpc = normalizeKeys(await downloadServicesRpc(SERVICES_RPC_URL));
    const files = readConfigFiles(CONF_DIR);

    for (const chain of relayChains) {
        console.log(`\nProcessing files for ${chain.charAt(0).toUpperCase() + chain.slice(1)}:`);
        const chainFiles = files.filter(file => file.toLowerCase().includes(chain));

        for (const file of chainFiles) {
            const filePath = path.join(CONF_DIR, file);
            const servers = extractServerAddresses(filePath);
            const configName = file.split(/-(.*)/s)[1].replace('.cfg', '').toLowerCase();
            const config = servicesRpc[configName];

            if (!config) {
                console.error(`No configuration found for ${configName}`);
                continue;
            }

            const expectedNetworkName = config.Configuration.NetworkName;

            for (const server of servers) {
                const wsUrl = `ws://${server.ip}:${server.port}`;
                try {
                    const chainName = await getChainName(wsUrl);
                    if (chainName !== expectedNetworkName) {
                        console.error(`Mismatch: File: ${file}, Server: ${wsUrl}, Expected: ${expectedNetworkName}, Got: ${chainName}`);
                    }
                } catch (error) {
                    console.error(`Failed to connect to ${wsUrl}:`, error.message);
                }
            }
        }
    }
};

processFiles().catch(console.error);
