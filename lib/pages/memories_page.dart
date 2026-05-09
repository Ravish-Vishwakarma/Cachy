import 'package:cachy/database/database_helper.dart';
import 'package:cachy/model/memories_model.dart';
import 'package:cachy/widget/create_memory_dialog.dart';
import 'package:cachy/widget/delete_conform_dialog.dart';
import 'package:cachy/widget/memory_detail.dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DatabasePage extends StatefulWidget {
  const DatabasePage({super.key});

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  final TextEditingController searchController = TextEditingController();
  final db = DatabaseHelper.instance;
  List<Memories> memories = [];
  List<Memories> allMemories = [];
  void createNewMemory(String memory) async {
    await db.createMemory(
      Memories(data: memory, time: DateTime.now().millisecondsSinceEpoch),
    );
  }

  void searchMemories(String query) {
    final filtered = allMemories.where((memory) {
      return memory.data.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      memories = filtered;
    });
  }

  Future<void> loadMemories() async {
    final data = await db.getMemories();

    setState(() {
      setState(() {
        allMemories = data;
        memories = data;
      });
    });
  }

  void deleteMemory(id, index) async {
    await db.deleteMemory(id);
    setState(() {
      memories.removeAt(index);
    });
  }

  Future<void> refreshMemories() async {
    searchController.clear();
    setState(() {
      showSearchBar = false;
    });
    await loadMemories();
  }

  @override
  void initState() {
    loadMemories();
    super.initState();
  }

  String selectedItem = 'None';
  var showSearchBar = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("MEMORIES", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF093176),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                showSearchBar = !showSearchBar;
              });
            },
            icon: Icon(Icons.search_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: "Reload",
            onPressed: () {
              refreshMemories();
            },
            icon: Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await refreshMemories();
        },
        child: Column(
          children: [
            if (showSearchBar)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: SearchBar(
                  controller: searchController,
                  autoFocus: true,
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                  leading: Icon(Icons.search_rounded),
                  hintText: "Search Memories",
                  onChanged: (value) {
                    searchMemories(value);
                  },
                ),
              ),
            Expanded(
              child: memories.isNotEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: memories.length, // Total number of items
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return MemoryDetailDialog(
                                  memory: memories[index],
                                );
                              },
                            );
                          },

                          title: Text(
                            memories[index].data,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            "${DateFormat('hh:mmaa dd/MMM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(memories[index].time))}",
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return DeleteConformDialog(
                                    onDelete: () {
                                      deleteMemory(memories[index].id, index);
                                    },
                                  );
                                },
                              );
                            },
                            icon: Icon(
                              Icons.delete_rounded,
                              color: Colors.red[400],
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("No Result", style: TextStyle(fontSize: 20)),
                          TextButton(
                            onPressed: () {
                              refreshMemories();
                            },
                            child: Text("Clear"),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return CreateMemoryDialog(
                onSave: (memory) {
                  createNewMemory(memory);
                  loadMemories();
                },
              );
            },
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
