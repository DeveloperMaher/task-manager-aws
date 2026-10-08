<x-app-layout>
    <x-slot name="header">
        <div class="flex justify-between items-center">
            <h2 class="font-semibold text-xl text-gray-800">My Tasks</h2>
            <a href="{{ route('tasks.create') }}" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
                + New Task
            </a>
        </div>
    </x-slot>

    <div class="py-12">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8">
            @if(session('success'))
                <div class="mb-4 p-4 bg-green-100 text-green-800 rounded">{{ session('success') }}</div>
            @endif

            <div class="bg-white overflow-hidden shadow-sm sm:rounded-lg">
                <div class="p-6 bg-white">
                    @forelse($tasks as $task)
                        <div class="border-b py-4 flex justify-between items-center">
                            <div>
                                <h3 class="font-bold text-lg">{{ $task->title }}</h3>
                                <p class="text-sm text-gray-600">{{ $task->description }}</p>
                                <span class="text-xs px-2 py-1 rounded
                                    @if($task->status === 'done') bg-green-200
                                    @elseif($task->status === 'in_progress') bg-yellow-200
                                    @else bg-gray-200 @endif">
                                    {{ $task->status }}
                                </span>
                            </div>
                            <div class="space-x-2">
                                <a href="{{ route('tasks.edit', $task) }}" class="text-blue-600">Edit</a>
                                <form action="{{ route('tasks.destroy', $task) }}" method="POST" class="inline">
                                    @csrf @method('DELETE')
                                    <button class="text-red-600" onclick="return confirm('Delete?')">Delete</button>
                                </form>
                            </div>
                        </div>
                    @empty
                        <p class="text-gray-500">No tasks yet. Create your first one!</p>
                    @endforelse

                    <div class="mt-4">{{ $tasks->links() }}</div>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>