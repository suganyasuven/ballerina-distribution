// Copyright (c) 2020 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/lang.'string as strings;
import ballerina/mime;
import ballerina/test;

listener http:Listener passthroughEP1 = new(9113);

service http:Service /passthrough on passthroughEP1 {

    resource function get .(http:Caller caller, http:Request clientRequest) {
        http:Client nyseEP1 = checkpanic new("http://localhost:9113");
        http:Response|error response = nyseEP1->get("/nyseStock/stocks");
        if (response is http:Response) {
            checkpanic caller->respond(<@untainted> response);
        } else {
            checkpanic caller->respond({ "error": "error occurred while invoking the service" });
        }
    }

    resource function post forwardMultipart(http:Caller caller, http:Request clientRequest) {
        http:Client nyseEP1 = checkpanic new("http://localhost:9113");
        http:Response|error response = nyseEP1->forward("/nyseStock/stocksAsMultiparts", clientRequest);
        if (response is http:Response) {
            checkpanic caller->respond(<@untainted> response);
        } else {
            checkpanic caller->respond({ "error": "error occurred while invoking the service" });
        }
    }

    resource function post forward(http:Request clientRequest) returns @tainted http:Ok|http:InternalServerError {
        http:Client nyseEP1 = checkpanic new("http://localhost:9113");
        http:Response|error response = nyseEP1->forward("/nyseStock/entityCheck", clientRequest);
        if (response is http:Response) {
            var entity = response.getEntity();
            if (entity is mime:Entity) {
                string|error payload = entity.getText();
                if (payload is string) {
                    http:Ok ok = {body: payload + ", " + checkpanic entity.getHeader("X-check-header")};
                    return ok;
                } else {
                    http:InternalServerError err = {body: payload.toString()};
                    return err;
                }
            } else {
                http:InternalServerError err = {body: entity.toString()};
                return err;
            }
        } else {
            http:InternalServerError err = {body: (<error>response).toString()};
            return err;
        }
    }
}

service http:Service /nyseStock on passthroughEP1 {

    resource function get stocks(http:Caller caller) {
        checkpanic caller->respond({ "exchange": "nyse", "name": "IBM", "value": "127.50" });
    }

    resource function post stocksAsMultiparts(http:Caller caller, http:Request clientRequest) {
        var bodyParts = clientRequest.getBodyParts();
        if (bodyParts is mime:Entity[]) {
            checkpanic caller->respond(<@untainted> bodyParts);
        } else {
            checkpanic caller->respond(<@untainted> bodyParts.message());
        }
    }

    resource function post entityCheck(http:Caller caller, http:Request clientRequest) returns http:InternalServerError? {
        http:Response res = new;
        var entity = clientRequest.getEntity();
        if (entity is mime:Entity) {
            json|error textPayload = entity.getText();
            if (textPayload is string) {
                mime:Entity ent = new;
                ent.setText(<@untainted> ("payload :" + textPayload + ", header: " + checkpanic entity.getHeader("Content-type")));
                ent.setHeader("X-check-header", "entity-check-header");
                res.setEntity(ent);
                checkpanic caller->respond(res);
            } else {
                return {body: "Error while retrieving from entity"};
            }
        } else {
            return {body: "Error while retrieving from request"};
        }
        return;
    }
}

@test:Config {}
public function testPassthroughServiceByBasePath() {
    http:Client httpClient = checkpanic new("http://localhost:9113");
    http:Response|error resp = httpClient->get("/passthrough");
    if (resp is http:Response) {
        string contentType = checkpanic resp.getHeader("content-type");
        test:assertEquals(contentType, "application/json");
        var body = resp.getJsonPayload();
        if (body is json) {
            test:assertEquals(body.toJsonString(), "{\"exchange\":\"nyse\", \"name\":\"IBM\", \"value\":\"127.50\"}");
        } else {
            test:assertFail(msg = "Found unexpected output: " + body.message());
        }
    } else {
        test:assertFail(msg = "Found unexpected output: " +  (<error>resp).message());
    }
}

@test:Config {}
public function testPassthroughServiceWithMimeEntity() {
    http:Client httpClient = checkpanic new("http://localhost:9113");
    http:Response|error resp = httpClient->post("/passthrough/forward", "Hello from POST!");
    if (resp is http:Response) {
        string contentType = checkpanic resp.getHeader("content-type");
        test:assertEquals(contentType, "text/plain");
        var body = resp.getTextPayload();
        if (body is string) {
            test:assertEquals(body, "payload :Hello from POST!, header: text/plain, entity-check-header");
        } else {
            test:assertFail(msg = "Found unexpected output: " + body.message());
        }
    } else {
        test:assertFail(msg = "Found unexpected output: " +  (<error>resp).message());
    }
}

@test:Config {}
public function testPassthroughWithMultiparts() {
    http:Client httpClient = checkpanic new("http://localhost:9113");
    mime:Entity textPart1 = new;
    textPart1.setText("Part1");
    textPart1.setHeader("Content-Type", "text/plain; charset=UTF-8");

    mime:Entity textPart2 = new;
    textPart2.setText("Part2");
    textPart2.setHeader("Content-Type", "text/plain");

    mime:Entity[] bodyParts = [textPart1, textPart2];
    http:Request request = new;
    request.setBodyParts(bodyParts, contentType = mime:MULTIPART_FORM_DATA);
    http:Response|error resp = httpClient->post("/passthrough/forwardMultipart", request);
    if (resp is http:Response) {
        string contentType = checkpanic resp.getHeader("content-type");
        test:assertTrue(strings:includes(contentType, "multipart/form-data"));
        var respBodyParts = resp.getBodyParts();
        if (respBodyParts is mime:Entity[]) {
            test:assertEquals(respBodyParts.length(), 2);
            string|error textPart = respBodyParts[0].getText();
            if (textPart is string) {
                test:assertEquals(textPart, "Part1");
            } else {
                test:assertFail(msg = "Found an unexpected output: " + textPart.message());
            }
            string|error txtPart2 = respBodyParts[1].getText();
            if (txtPart2 is string) {
                test:assertEquals(txtPart2, "Part2");
            } else {
                test:assertFail(msg = "Found an unexpected output: " + txtPart2.message());
            }
        }
    } else {
        test:assertFail(msg = "Found unexpected output: " +  (<error>resp).message());
    }
}
