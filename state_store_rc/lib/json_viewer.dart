library flutter_json_widget;

import 'package:flutter/material.dart';

typedef OnSelected = void Function(String? key, dynamic value);

class JsonViewer extends StatefulWidget {
  final dynamic jsonObj;
  final OnSelected? onSelected;
  const JsonViewer(this.jsonObj, {key, this.onSelected}) : super(key: key);
  @override
  State createState() => _JsonViewerState();
}

class _JsonViewerState extends State<JsonViewer> {
  @override
  Widget build(BuildContext context) {
    return getContentWidget(widget.jsonObj, widget.onSelected);
  }

  static getContentWidget(dynamic content, OnSelected? onSelected) {
    if (content == null) {
      return const Text('{}');
    } else if (content is List) {
      return JsonArrayViewer(
        content,
        notRoot: false,
        onSelected: onSelected,
      );
    } else {
      return JsonObjectViewer(
        content,
        notRoot: false,
        onSelected: onSelected,
      );
    }
  }
}

class JsonObjectViewer extends StatefulWidget {
  final Map<String, dynamic> jsonObj;
  final OnSelected? onSelected;
  final bool notRoot;

  const JsonObjectViewer(this.jsonObj,
      {key, this.notRoot = false, this.onSelected})
      : super(key: key);

  @override
  JsonObjectViewerState createState() => JsonObjectViewerState();
}

class JsonObjectViewerState extends State<JsonObjectViewer> {
  Map<String, bool> openFlag = {};

  @override
  Widget build(BuildContext context) {
    if (widget.notRoot) {
      return Container(
        padding: const EdgeInsets.only(left: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _getList(),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _getList(),
    );
  }

  _getList() {
    List<Widget> list = [];
    for (MapEntry entry in widget.jsonObj.entries) {
      bool ex = isExtensible(entry.value);
      bool ink = isInkWell(entry.value);
      String title =
          entry.key == 'root' ? 'Compartment: ${entry.value['id']}' : entry.key;
      list.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ex
              ? ((openFlag[entry.key] ?? false)
                  ? Icon(Icons.arrow_drop_down,
                      size: 14, color: Colors.grey[700])
                  : Icon(Icons.arrow_right, size: 14, color: Colors.grey[700]))
              : const Icon(
                  Icons.arrow_right,
                  color: Color.fromARGB(0, 0, 0, 0),
                  size: 14,
                ),
          (ex && ink)
              ? InkWell(
                  child:
                      Text(title, style: TextStyle(color: Colors.purple[900])),
                  onTap: () {
                    setState(() {
                      widget.onSelected
                          ?.call(entry.key?.toString(), entry.value);
                      openFlag[entry.key] = !(openFlag[entry.key] ?? false);
                    });
                  })
              : wrapWithListener(
                  Text(entry.key,
                      style: TextStyle(
                          color: entry.value == null
                              ? Colors.grey
                              : Colors.purple[900])),
                  entry.key,
                  entry.value,
                  widget.onSelected,
                ),
          const Text(
            ':',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(width: 3),
          getValueWidget(entry, widget.onSelected)
        ],
      ));
      list.add(const SizedBox(height: 4));
      if (openFlag[entry.key] ?? false) {
        list.add(getContentWidget(entry.value, widget.onSelected));
      }
    }
    return list;
  }

  static getContentWidget(dynamic content, OnSelected? onSelected) {
    if (content is List) {
      return JsonArrayViewer(content, notRoot: true, onSelected: onSelected);
    } else {
      return JsonObjectViewer(content, notRoot: true, onSelected: onSelected);
    }
  }

  static isInkWell(dynamic content) {
    if (content != null && content is List && content.isNotEmpty) {
      return true;
    }
    return false;
  }

  getValueWidget(MapEntry entry, OnSelected? onSelected) {
    if (entry.value == null) {
      return const Expanded(
          child: Text(
        'undefined',
        style: TextStyle(color: Colors.grey),
      ));
    } else if (entry.value is int) {
      return Expanded(
          child: Text(
        entry.value.toString(),
        style: const TextStyle(color: Colors.teal),
      ));
    } else if (entry.value is String) {
      return Expanded(
          child: Text(
        '"${entry.value}"',
        style: const TextStyle(color: Colors.redAccent),
      ));
    } else if (entry.value is bool) {
      return Expanded(
          child: Text(
        entry.value.toString(),
        style: const TextStyle(color: Colors.purple),
      ));
    } else if (entry.value is double) {
      return Expanded(
          child: Text(
        entry.value.toString(),
        style: const TextStyle(color: Colors.teal),
      ));
    } else if (entry.value is List) {
      if (entry.value.isEmpty) {
        return const Text(
          'Array[0]',
          style: TextStyle(color: Colors.grey),
        );
      } else {
        return InkWell(
            child: Text(
              'Array<${getTypeName(entry.value[0])}>[${entry.value.length}]',
              style: const TextStyle(color: Colors.grey),
            ),
            onTap: () {
              setState(() {
                widget.onSelected?.call(entry.key?.toString(), entry.value);
                openFlag[entry.key] = !(openFlag[entry.key] ?? false);
              });
            });
      }
    }
    return InkWell(
        child: const Text(
          'Object',
          style: TextStyle(color: Colors.grey),
        ),
        onTap: () {
          setState(() {
            widget.onSelected?.call(entry.key?.toString(), entry.value);
            openFlag[entry.key] = !(openFlag[entry.key] ?? false);
          });
        });
  }

  static InkWell wrapWithListener(
      Widget child, String key, dynamic value, OnSelected? onSelected) {
    return InkWell(
        child: child,
        onTap: () {
          onSelected?.call(key, value);
        });
  }

  static isExtensible(dynamic content) {
    if (content == null) {
      return false;
    } else if (content is int) {
      return false;
    } else if (content is String) {
      return false;
    } else if (content is bool) {
      return false;
    } else if (content is double) {
      return false;
    }
    return true;
  }

  static getTypeName(dynamic content) {
    if (content is int) {
      return 'int';
    } else if (content is String) {
      return 'String';
    } else if (content is bool) {
      return 'bool';
    } else if (content is double) {
      return 'double';
    } else if (content is List) {
      return 'List';
    }
    return 'Object';
  }
}

class JsonArrayViewer extends StatefulWidget {
  final List<dynamic> jsonArray;
  final OnSelected? onSelected;

  final bool notRoot;

  const JsonArrayViewer(
    this.jsonArray, {
    Key? key,
    this.notRoot = false,
    this.onSelected,
  }) : super(key: key);

  @override
  State createState() => _JsonArrayViewerState();
}

class _JsonArrayViewerState extends State<JsonArrayViewer> {
  late List<bool> openFlag;

  @override
  Widget build(BuildContext context) {
    if (widget.notRoot) {
      return Container(
          padding: const EdgeInsets.only(left: 14.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _getList()));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: _getList());
  }

  @override
  void initState() {
    super.initState();
    openFlag = List.filled(widget.jsonArray.length, false);
  }

  _getList() {
    List<Widget> list = [];
    int i = 0;
    for (dynamic content in widget.jsonArray) {
      bool ex = JsonObjectViewerState.isExtensible(content);
      bool ink = JsonObjectViewerState.isInkWell(content);
      list.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ex
              ? ((openFlag[i])
                  ? Icon(Icons.arrow_drop_down,
                      size: 14, color: Colors.grey[700])
                  : Icon(Icons.arrow_right, size: 14, color: Colors.grey[700]))
              : const Icon(
                  Icons.arrow_right,
                  color: Color.fromARGB(0, 0, 0, 0),
                  size: 14,
                ),
          (ex && ink)
              ? getInkWell(content, i)
              : Text('[$i]',
                  style: TextStyle(
                      color:
                          content == null ? Colors.grey : Colors.purple[900])),
          const Text(
            ':',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(width: 3),
          getValueWidget(content, i)
        ],
      ));
      list.add(const SizedBox(height: 4));
      if (openFlag[i]) {
        list.add(
            JsonObjectViewerState.getContentWidget(content, widget.onSelected));
      }
      i++;
    }
    return list;
  }

  String _t(int val) {
    if (val < 10) {
      return '0$val';
    }
    return val.toString();
  }

  String _ms(int val) {
    if (val < 10) {
      return '00$val';
    } else if (val < 100) {
      return '0$val';
    }
    return val.toString();
  }

  String _formatDate(dynamic content, int index) {
    if (content['lastModifiedDate'] != null) {
      var d = DateTime.fromMillisecondsSinceEpoch(content['lastModifiedDate']);
      return "${_t(d.day)}.${_t(d.month)}.${_t(d.year)} ${d.hour}:${_t(d.minute)}.${_t(d.second)}.${_ms(d.millisecond)}";
    } else {
      return index.toString();
    }
  }

  getInkWell(dynamic content, int index) {
    String title = _formatDate(content, index);
    return InkWell(
        child: Text('[$title], id: ${content['id']} ${content['name'] ?? ''}',
            style: TextStyle(color: Colors.purple[900])),
        onTap: () {
          setState(() {
            widget.onSelected?.call(content['id']?.toString(), title);
            openFlag[index] = !(openFlag[index]);
          });
        });
  }

  getValueWidget(dynamic content, int index) {
    if (content == null) {
      return const Expanded(
          child: Text(
        'undefined',
        style: TextStyle(color: Colors.grey),
      ));
    } else if (content is int) {
      return Expanded(
          child: Text(
        content.toString(),
        style: const TextStyle(color: Colors.teal),
      ));
    } else if (content is String) {
      return Expanded(
          child: Text(
        '"$content"',
        style: const TextStyle(color: Colors.redAccent),
      ));
    } else if (content is bool) {
      return Expanded(
          child: Text(
        content.toString(),
        style: const TextStyle(color: Colors.purple),
      ));
    } else if (content is double) {
      return Expanded(
          child: Text(
        content.toString(),
        style: const TextStyle(color: Colors.teal),
      ));
    } else if (content is List) {
      if (content.isEmpty) {
        return const Text(
          'Array[0]',
          style: TextStyle(color: Colors.grey),
        );
      } else {
        return InkWell(
            child: Text(
              'Array<${JsonObjectViewerState.getTypeName(content)}>[${content.length}]',
              style: const TextStyle(color: Colors.grey),
            ),
            onTap: () {
              setState(() {
                widget.onSelected?.call(index.toString(), 'array');
                openFlag[index] = !(openFlag[index]);
              });
            });
      }
    }
    return InkWell(
        child: const Text(
          'Object',
          style: TextStyle(color: Colors.grey),
        ),
        onTap: () {
          setState(() {
            widget.onSelected?.call(content['id']?.toString(), 'leaf');
            openFlag[index] = !(openFlag[index]);
          });
        });
  }
}
