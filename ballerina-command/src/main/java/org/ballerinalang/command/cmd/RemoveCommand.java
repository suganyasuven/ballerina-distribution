/*
 * Copyright (c) 2019, WSO2 Inc. (http://wso2.com) All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.ballerinalang.command.cmd;

import org.ballerinalang.command.BallerinaCliCommands;
import org.ballerinalang.command.util.ErrorUtil;
import org.ballerinalang.command.util.ToolUtil;
import picocli.CommandLine;

import java.io.File;
import java.io.IOException;
import java.io.PrintStream;
import java.util.List;

import static org.ballerinalang.command.util.OSUtils.deleteFiles;

/**
 * This class represents the "Remove" command and it holds arguments and flags specified by the user.
 */
@CommandLine.Command(name = "remove", description = "Remove Ballerina distribution")
public class RemoveCommand extends Command implements BCommand {

    @CommandLine.Parameters(description = "Command name")
    private List<String> removeCommands;

    @CommandLine.Option(names = {"--help", "-h", "?"}, hidden = true)
    private boolean helpFlag;

    private CommandLine parentCmdParser;

    public RemoveCommand(PrintStream printStream) {
        super(printStream);
    }

    public void execute() {
        if (helpFlag) {
            printUsageInfo(ToolUtil.CLI_HELP_FILE_PREFIX + BallerinaCliCommands.REMOVE);
            return;
        }

        if (removeCommands == null || removeCommands.size() == 0) {
            throw ErrorUtil.createDistributionRequiredException("remove");
        }

        if (removeCommands.size() > 1) {
            throw ErrorUtil.createDistSubCommandUsageExceptionWithHelp("too many arguments",
                                                                       BallerinaCliCommands.REMOVE);
        }

        ToolUtil.handleInstallDirPermission();
        remove(removeCommands.get(0));
    }

    @Override
    public String getName() {
        return BallerinaCliCommands.REMOVE;
    }

    @Override
    public void printLongDesc(StringBuilder out) {

    }

    @Override
    public void printUsage(StringBuilder out) {
        out.append("  ballerina dist remove\n");
    }

    @Override
    public void setParentCmdParser(CommandLine parentCmdParser) {
        this.parentCmdParser = parentCmdParser;
    }

    private void remove(String version) {
        boolean isCurrentVersion =
                version.equals(ToolUtil.BALLERINA_TYPE + "-" + ToolUtil.getCurrentBallerinaVersion());
        try {
            if (isCurrentVersion) {
                throw ErrorUtil.createCommandException("The active Ballerina distribution cannot be removed");
            } else {
                File directory = new File(ToolUtil.getDistributionsPath() + File.separator + version);
                if (directory.exists()) {
                        deleteFiles(directory.toPath(), getPrintStream(), version);
                    getPrintStream().println("Distribution '" + version + "' successfully removed");
                } else {
                    throw ErrorUtil.createCommandException("distribution '" + version + "' not found");
                }
            }
        } catch (IOException e) {
            throw ErrorUtil.createCommandException("error occurred while removing '" + version + "'");
        }
    }
}
