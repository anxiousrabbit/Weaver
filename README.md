# Weaver

Weaver is a machine learning based command and control application that was presented at Thotcon 2025. Weaver pairs with the companion application Seer.

Weaver uses simple steganography by processing text that is found in an image using Apple Silicon's NPU. The resulting text will be passed to ASH (API Shell) to be procoessed. Through this process, the command sent to Weaver will evade EDR detection. Once the command is processed, Weaver will create another image with text in it and send it back to Seer at which point Seer will output the results.

Seer: https://github.com/anxiousrabbit/Seer


## Features

- Apple Silicon native
- EDR evasion
- Local machine learning


## Installation

To install Weaver, clone both Seer (follow Seer's instructions) and Weaver. Create an Xcode project and import Weaver's files into the new project. 

Import ASH into the Xcode project (https://github.com/anxiousrabbit/ASH) by following the instructions within the ASH repo.

Rename `variables.example.swift` to `variables.swift` and enter the required variables that are returned when you run Seer's Terraform.
