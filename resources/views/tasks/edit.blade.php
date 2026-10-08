<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">Edit Task</h2></x-slot>

    <div class="py-12">
        <div class="max-w-2xl mx-auto sm:px-6 lg:px-8">
            <form method="POST" action="{{ route('tasks.update', $task) }}" class="bg-white p-6 rounded shadow">
                @csrf @method('PUT')
                <div class="mb-4">
                    <label class="block font-medium">Title</label>
                    <input type="text" name="title" value="{{ old('title', $task->title) }}" class="w-full border rounded p-2" required>
                </div>
                <div class="mb-4">
                    <label class="block font-medium">Description</label>
                    <textarea name="description" class="w-full border rounded p-2">{{ old('description', $task->description) }}</textarea>
                </div>
                <div class="mb-4">
                    <label class="block font-medium">Status</label>
                    <select name="status" class="w-full border rounded p-2">
                        @foreach(['pending','in_progress','done'] as $s)
                            <option value="{{ $s }}" @selected($task->status === $s)>{{ $s }}</option>
                        @endforeach
                    </select>
                </div>
                <button class="bg-blue-600 text-white px-4 py-2 rounded">Update</button>
            </form>
        </div>
    </div>
</x-app-layout>