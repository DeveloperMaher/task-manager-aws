<?php

namespace App\Http\Controllers;

use App\Models\Task;
use Illuminate\Http\Request;

class TaskController extends Controller
{
    public function index()
    {
        $tasks = auth()->user()->tasks()->latest()->paginate(10);
        return view('tasks.index', compact('tasks'));
    }

    public function create()
    {
        return view('tasks.create');
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'title'       => 'required|string|max:255',
            'description' => 'nullable|string',
            'status'      => 'in:pending,in_progress,done',
            'attachment'  => 'nullable|file|max:5120',
        ]);

        if ($request->hasFile('attachment')) {
            // $path = $request->file('attachment')->store('tasks/attachments', 's3');
            $path = $request->file('attachment')->store('tasks/attachments', config('filesystems.default'));
            $validated['attachment_path'] = $path;
        }

        $task = auth()->user()->tasks()->create($validated);

        app(\App\Services\SnsService::class)->publish(
            'New Task Created',
            "Task '{$task->title}' was created by {$request->user()->email}"
        );

        return redirect()->route('tasks.index')->with('success', 'Task created!');
    }

    public function show(Task $task)
    {
        $this->authorize('view', $task);
        return view('tasks.show', compact('task'));
    }

    public function edit(Task $task)
    {
        $this->authorize('update', $task);
        return view('tasks.edit', compact('task'));
    }

    public function update(Request $request, Task $task)
    {
        $this->authorize('update', $task);

        $validated = $request->validate([
            'title'       => 'required|string|max:255',
            'description' => 'nullable|string',
            'status'      => 'in:pending,in_progress,done',
        ]);

        $task->update($validated);
        return redirect()->route('tasks.index')->with('success', 'Task updated!');
    }

    public function destroy(Task $task)
    {
        $this->authorize('delete', $task);
        // if ($task->attachment_path) {
        //     \Storage::disk('s3')->delete($task->attachment_path);
        // }
        if ($task->attachment_path) {
            \Storage::disk(config('filesystems.default'))->delete($task->attachment_path);
        }
        $task->delete();
        return redirect()->route('tasks.index')->with('success', 'Task deleted!');
    }
}