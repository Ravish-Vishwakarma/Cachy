import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cachy/database/database_helper.dart';
import 'package:cachy/model/memories_model.dart';
import 'package:cachy/widget/snackbar_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const String _modelUrl =
    "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm";
const int _expectedModelSize = 2583085056; // 2.58 GB

class AIPage extends StatefulWidget {
  const AIPage({super.key});

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  // ======================= VARIABLES ======================= //
  final classificationPrompt =
      '''You are a memory classifier. Determine whether the user wants to READ from memory/database or WRITE to memory/database.

Rules:
- If the user is asking for information, classify as "read" and return concise search keywords.
- If the user is providing information to save, classify as "write" and return a clean, formalized memory sentence.
- Respond ONLY in valid JSON.

Format:
{"type":"read|write","data":"keywords or formatted memory"}

USER:''';

  final memoryFindingPrompt =
      '''You are a memory retrieval agent. Your task is to find the most relevant memories for the user's request from the provided memory list and combine them into a natural response.

Rules:
- Use only the provided memories.
- Return a concise, human-readable sentence.
- If multiple memories are relevant, combine them naturally.
- If no relevant memory exists, respond with: "I could not find any relevant memory."
- Do not invent or assume information.
- Respond ONLY in valid JSON.

Format:
{"response":"natural language answer"}

USER REQUEST:
{{user_request}}

MEMORIES:
{{memory_list}}''';
  LiteLmEngine? engine;
  LiteLmConversation? conversation;

  var prompt = TextEditingController();
  var response = "";

  bool isDeeperSearch = false;
  bool isPermissionGranted = true;
  bool isModelDownloaded = true;
  bool isDownloading = false;
  bool isPaused = false;
  bool isGenerating = false;
  bool isLoading = true;
  int downloadProgress = 0;
  String? downloadTaskId;
  int memoriesCount = 0;
  Timer? _downloadTimer;

  // ======================= FUNCTIONS ======================= //

  // Used for showing any string in the response area of the app
  void showResponse(String resp) {
    setState(() {
      response = resp;
      isGenerating = false;
    });
    prompt.clear();
  }

  // Used for granting permission to read the downloaded model file
  Future<void> requestPermission() async {
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      setState(() {
        isPermissionGranted = true;
      });
    } else if (status.isDenied) {
      setState(() {
        isPermissionGranted = false;
      });
    } else if (status.isPermanentlyDenied) {
      setState(() {
        isPermissionGranted = false;
      });
      openAppSettings();
    }
  }

  // Used to convert json string from model to json type
  dynamic jsonifyResponse(String response) {
    try {
      final cleanedResponse = response
          .replaceFirst(RegExp(r'^```json\s*'), '')
          .replaceFirst(RegExp(r'```$'), '')
          .trim();

      return jsonDecode(cleanedResponse);
    } catch (e) {
      return null;
    }
  }

  // Used to search for memories with matching keywords
  Future<List<Memory>> getKeywordMatchingMemories(List<String> keywords) async {
    return await db.searchMemories(keywords);
  }

  // Used to convert Memories into formatted string to feed in AI models
  Future<String> getMemoriesString(List<Memory> memories) async {
    return memories
        .asMap()
        .entries
        .map((entry) {
          int index = entry.key + 1;
          Memory memory = entry.value;

          return "$index. ${memory.data}";
        })
        .join("\n");
  }

  // Used for loading the model from the app directory or copy it from the downloads folder
  String get localModelPath => "$_appDirPath/gemma-4-E2B-it.litertlm";

  String _appDirPath = "";

  Future<void> loadModel() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _appDirPath = appDir.path;

      final localModelFile = File(localModelPath);

      if (await localModelFile.exists()) {
        final fileSize = await localModelFile.length();
        if (fileSize < _expectedModelSize * 0.95) {
          await localModelFile.delete();
          setState(() {
            isModelDownloaded = false;
          });
          showResponse(
            "Model file is corrupted ($fileSize of $_expectedModelSize bytes). Please re-download.",
          );
          return;
        }
      }

      if (!await localModelFile.exists()) {
        if (Platform.isAndroid) {
          final sourceFile = File(
            "/storage/emulated/0/Download/gemma-4-E2B-it.litertlm",
          );

          if (await sourceFile.exists()) {
            final srcSize = await sourceFile.length();
            if (srcSize >= _expectedModelSize * 0.95) {
              await sourceFile.copy(localModelPath);
            }
          }
        }
      }

      if (await localModelFile.exists()) {
        engine = await LiteLmEngine.create(
          LiteLmEngineConfig(
            modelPath: localModelPath,
            backend: LiteLmBackend.cpu,
          ),
        );

        conversation = await engine!.createConversation(
          LiteLmConversationConfig(
            systemInstruction: "You are a helpful assistant.",
          ),
        );

        setState(() {
          isLoading = false;
          isModelDownloaded = true;
          response = "";
        });
      } else {
        setState(() {
          isLoading = false;
          isModelDownloaded = false;
        });
        showResponse("Model not found. Please download it.");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isModelDownloaded = false;
      });
      showResponse("Error loading model: ${e.toString()}");
    }
  }

  // Downloads the model from hugging face into your app directory
  Future<void> downloadModel() async {
    setState(() {
      isDownloading = true;
      downloadProgress = 0;
      response = "";
    });

    // Start polling for progress
    _startDownloadPolling();

    final appDir = await getApplicationDocumentsDirectory();

    try {
      // Remove any existing file to avoid name conflicts
      final existing = File("${appDir.path}/gemma-4-E2B-it.litertlm");
      if (await existing.exists()) {
        await existing.delete();
      }

      final taskId = await FlutterDownloader.enqueue(
        url: _modelUrl,
        savedDir: appDir.path,
        fileName: "gemma-4-E2B-it.litertlm",
        showNotification: true,
        openFileFromNotification: false,
      );

      if (taskId != null) {
        downloadTaskId = taskId;
      }
    } catch (e) {
      _downloadTimer?.cancel();
      setState(() {
        isDownloading = false;
        isPaused = false;
      });
      showResponse("Download error: ${e.toString()}");
    }
  }

  void _startDownloadPolling() {
    _downloadTimer?.cancel();
    _downloadTimer = Timer.periodic(Duration(seconds: 2), (_) async {
      if (downloadTaskId == null) return;
      final tasks = await FlutterDownloader.loadTasks();
      if (tasks == null) return;

      for (final task in tasks) {
        if (task.taskId == downloadTaskId) {
          setState(() {
            downloadProgress = task.progress;
            isPaused = task.status == DownloadTaskStatus.paused;
          });

          if (task.status == DownloadTaskStatus.complete) {
            _downloadTimer?.cancel();
            setState(() {
              isDownloading = false;
              isPaused = false;
              downloadTaskId = null;
            });
            loadModel();
          } else if (task.status == DownloadTaskStatus.failed ||
              task.status == DownloadTaskStatus.canceled) {
            _downloadTimer?.cancel();
            setState(() {
              isDownloading = false;
              isPaused = false;
              downloadTaskId = null;
            });
            showResponse("Download failed. Please try again.");
          }
          break;
        }
      }
    });
  }

  // Pauses the current download
  Future<void> pauseDownload() async {
    if (downloadTaskId != null) {
      await FlutterDownloader.pause(taskId: downloadTaskId!);
    }
  }

  // Resumes the paused download
  Future<void> resumeDownload() async {
    if (downloadTaskId != null) {
      await FlutterDownloader.resume(taskId: downloadTaskId!);
    }
  }

  // Cancels the current download
  Future<void> cancelDownload() async {
    if (downloadTaskId != null) {
      await FlutterDownloader.cancel(taskId: downloadTaskId!);
    }
    _downloadTimer?.cancel();
    setState(() {
      isDownloading = false;
      isPaused = false;
      downloadProgress = 0;
      downloadTaskId = null;
    });
  }

  // Used for searching bigger chunks of memories for a deeper search
  List<String> splitIntoChunks(String text, {int maxLength = 10000}) {
    List<String> chunks = [];

    while (text.isNotEmpty) {
      if (text.length <= maxLength) {
        chunks.add(text.trim());
        break;
      }

      int splitIndex = text.lastIndexOf('\n', maxLength);

      if (splitIndex == -1) {
        splitIndex = maxLength;
      }

      chunks.add(text.substring(0, splitIndex).trim());

      text = text.substring(splitIndex).trim();
    }

    return chunks;
  }

  // Search every memory to find the answer
  Future<void> deeperSearch() async {
    try {
      final memories = await db.getMemories();
      final allmemo = await getMemoriesString(memories);
      List<String> listOfMemories = splitIntoChunks(allmemo);

      for (int i = 0; i < listOfMemories.length; i++) {
        final filterPrompt = memoryFindingPrompt
            .replaceFirst("{{memory_list}}", listOfMemories[i])
            .replaceAll("{{user_request}}", prompt.text);
        final reply = await conversation!.sendMessage(filterPrompt);
        final filteredMemory = jsonifyResponse(reply.text);
        if (filteredMemory != null &&
            !filteredMemory["response"].contains(
              "could not find any relevant memory",
            )) {
          showResponse(filteredMemory["response"]);
          break;
        }
      }
    } catch (e) {
      showResponse("Search error: ${e.toString()}");
    }
  }

  // Used for getting the total numbers of memories present in the app
  void getMemoriesCount() async {
    int count = await db.getMemoriesCount();
    setState(() {
      memoriesCount = count;
    });
  }

  @override
  void initState() {
    super.initState();
    requestPermission();
    loadModel();
    getMemoriesCount();
  }

  final db = DatabaseHelper.instance;

  @override
  void dispose() {
    prompt.dispose();
    _downloadTimer?.cancel();
    engine = null;
    conversation = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("CACHY", style: TextStyle(color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
            child: Text(
              "TOTAL MEMORIES: $memoriesCount",
              style: TextStyle(color: Colors.white),
            ),
          ),
          isPermissionGranted
              ? SizedBox.shrink()
              : IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("File Permission not Allowed"),
                          // content: RichText(
                          //   // "Please Allow File Permission to 'Allow management of all files' in Settings",
                          // ),
                          content: RichText(
                            text: TextSpan(
                              style: TextStyle(color: Colors.black),
                              children: [
                                TextSpan(
                                  text:
                                      "Please Allow File Permission and set it to: ",
                                ),
                                TextSpan(
                                  text: "'Allow management of all files' ",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: "in Settings."),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Close'),
                            ),
                            TextButton(
                              onPressed: () {
                                openAppSettings();
                              },
                              child: Text("Setting"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: Icon(Icons.error_outline, color: Colors.red),
                ),
        ],
        backgroundColor: const Color(0xFF093176),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 10),
            isModelDownloaded
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      controller: prompt,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        label: Text("Prompt"),
                      ),
                    ),
                  )
                : SizedBox.shrink(),
            isModelDownloaded
                ? ElevatedButton(
                    onPressed: isLoading | isGenerating
                        ? null
                        : () async {
                            if (prompt.text != "") {
                              setState(() {
                                isGenerating = true;
                              });
                              if (isLoading || conversation == null) {
                                showResponse("Model still loading...");
                                return;
                              }
                              final structuredPrompt =
                                  "$classificationPrompt${prompt.text}";
                              try {
                                final reply = await conversation!.sendMessage(
                                  structuredPrompt,
                                );
                                final requestType = jsonifyResponse(reply.text);

                                if (requestType == null) {
                                  showResponse(
                                    "Failed to understand the request. Please try again.",
                                  );
                                  return;
                                }

                                if (requestType["type"].toLowerCase() ==
                                    "write") {
                                  final data = Memory(
                                    data: requestType["data"],
                                    time: DateTime.now().millisecondsSinceEpoch,
                                  );
                                  await db.createMemory(data);
                                  showResponse("Added: ${requestType["data"]}");
                                }

                                if (requestType["type"].toLowerCase() ==
                                    "read") {
                                  final memories = await db.getMemories();
                                  final allmemo = await getMemoriesString(
                                    memories,
                                  );

                                  if (allmemo.length < 15000) {
                                    // length is okay
                                    final filterPrompt = memoryFindingPrompt
                                        .replaceFirst(
                                          "{{memory_list}}",
                                            allmemo,
                                        )
                                        .replaceAll(
                                          "{{user_request}}",
                                          prompt.text,
                                        );
                                    final reply = await conversation!
                                        .sendMessage(filterPrompt);
                                    final filteredMemory = jsonifyResponse(
                                      reply.text,
                                    );

                                    showResponse(
                                      filteredMemory != null
                                          ? filteredMemory["response"]
                                          : "No relevant memory found.",
                                    );
                                  } else {
                                    // above 15,000 technique
                                    final searchKeywords = requestType["data"]
                                        .split(" ");
                                    final filteredMemories =
                                        await getKeywordMatchingMemories(
                                          searchKeywords,
                                        );
                                    final allMemoString =
                                        await getMemoriesString(
                                          filteredMemories,
                                        );
                                    final filterPrompt = memoryFindingPrompt
                                        .replaceFirst(
                                          "{{memory_list}}",
                                          allMemoString,
                                        )
                                        .replaceAll(
                                          "{{user_request}}",
                                          prompt.text,
                                        );
                                    final reply = await conversation!
                                        .sendMessage(filterPrompt);
                                    final filteredMemory = jsonifyResponse(
                                      reply.text,
                                    );
                                    if (filteredMemory != null &&
                                        filteredMemory["response"].contains(
                                          "could not find any relevant memory",
                                        )) {
                                      setState(() {
                                        isDeeperSearch = true;
                                      });
                                    }
                                    showResponse(
                                      filteredMemory != null
                                          ? filteredMemory["response"]
                                          : "No relevant memory found.",
                                    );
                                  }
                                }

                                // showResponse(reply.text);
                              } catch (e) {
                                showResponse(e.toString());
                              }
                            } else {
                              SnackbarMessage.show(context, "Enter A Prompt");
                            }
                          },
                    child: Text(isLoading ? "Loading model..." : "Send"),
                  )
                : SizedBox.shrink(),
            isGenerating
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Generating...",
                      style: TextStyle(fontSize: 20),
                    ),
                  )
                : response == ""
                ? SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SelectableText(
                          response,
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),
            isModelDownloaded
                ? SizedBox.shrink()
                : !isDownloading
                ? ElevatedButton(
                    onPressed: () {
                      downloadModel();
                    },
                    child: Text("Download Model"),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: downloadProgress > 0
                              ? downloadProgress / 100.0
                              : null,
                        ),
                        SizedBox(height: 8),
                        Text("$downloadProgress%"),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            isPaused
                                ? ElevatedButton(
                                    onPressed: resumeDownload,
                                    child: Text("Resume"),
                                  )
                                : ElevatedButton(
                                    onPressed: pauseDownload,
                                    child: Text("Pause"),
                                  ),
                            SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: cancelDownload,
                              child: Text("Cancel"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            isDeeperSearch
                ? Column(
                    children: [
                      SizedBox(height: 40),
                      Text("Want Deeper Search?"),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isDeeperSearch = false;
                              });
                            },
                            child: Text("No"),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isDeeperSearch = false;
                              });
                              deeperSearch();
                            },
                            child: Text("Yes!"),
                          ),
                        ],
                      ),
                    ],
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}
