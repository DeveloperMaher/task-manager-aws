<x-app-layout>
    <x-slot name="header"><h2 class="font-semibold text-xl text-gray-800">New Task</h2></x-slot>

    <div class="py-12">
        <div class="max-w-2xl mx-auto sm:px-6 lg:px-8">
            <form method="POST" action="{{ route('tasks.store') }}" enctype="multipart/form-data" class="bg-white p-6 rounded shadow">
                @csrf
                <div class="mb-4">
                    <label class="block font-medium">Title</label>
                    <input type="text" name="title" value="{{ old('title') }}" class="w-full border rounded p-2" required>
                    @error('title') <p class="text-red-500 text-sm">{{ $message }}</p> @enderror
                </div>
                <div class="mb-4">
                    <label class="block font-medium">Description</label>
                    <textarea name="description" class="w-full border rounded p-2">{{ old('description') }}</textarea>
                </div>
                <div class="mb-4">
                    <label class="block font-medium">Status</label>
                    <select name="status" class="w-full border rounded p-2">
                        <option value="pending">Pending</option>
                        <option value="in_progress">In Progress</option>
                        <option value="done">Done</option>
                    </select>
                </div>
                <div class="mb-4">
                    <label class="block font-medium">Attachment (optional)</label>
                    <input type="file" name="attachment" class="w-full border rounded p-2">
                </div>
                <button class="bg-blue-600 text-white px-4 py-2 rounded">Save</button>
            </form>
        </div>
    </div>
</x-app-layout>