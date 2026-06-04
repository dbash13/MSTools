# ForEach-Object Parallel
By default, when we use `ForEach-Object`, it processes pipeline items sequentially, one after another.
Since PWSH 7, the `-Parallel` parameter has been added, making its behavior similar to `Jobs` but without invoking separate processes. That is, where a `job` creates a separate process, `parallel` creates a runspace within the same process (a thread).

Therefore, using `parallel` instead of `jobs` achieves almost the same isolation while reducing RAM usage, since it doesn't need to create extra processes, and startup is instantaneous.

## Number of Threads
By default, it uses 5 threads, but we can increase this limit by using `-ThrottleLimit` followed by the number of parallel threads we want running.

## Limitations of Parallel ForEach-Object
When using `-Parallel`, our context changes because it loses visibility over the main runspace variables.
If we want to pass a variable from the main context, we must invoke it using `$using:var`, just like we do with jobs.

## Out-of-Runspace Synchronization
When working with `-Parallel`, the real issue comes from the fact that we cannot easily access shared variables, such as a counter. Even if we have a `$counter` variable outside the context and invoke it with `$using:` to pass its reference, it will not affect the original variable.

This will not work:
```PowerShell
$counter = 0 

0..10 | ForEach-Object -Parallel {
    $c = $using:counter
    $c++
}
```

Microsoft's documentation [here](https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/write-progress-across-multiple-threads?view=powershell-7.5) does not shed much light on the matter. However, combining what it provides with ideas from other StackOverflow users [here](https://stackoverflow.com/questions/75251848/how-do-i-add-an-atomic-counter-to-a-powershell-foreach-parallel-loop), we can achieve the following by utilizing .NET classes:

```PowerShell
$totalItems = 10

$syncTable = [hashtable]::Synchronized(@{
    <#
        When creating the .NET object, (1,1) the first value defines the number 
        of threads that can enter concurrently to modify our object. The second
        value defines the maximum number of threads that can call it simultaneously.
        - https://learn.microsoft.com/en-us/dotnet/api/system.threading.semaphoreslim?view=net-10.0
    #>
    Semaphore = [System.Threading.SemaphoreSlim]::new(1,1)
    Counter = 0
}) 

0..10 | ForEach-Object -Parallel {
    $sync = $using:syncTable
    
    # Parallel processing
    # XXXX

    $sync.Semaphore.Wait() # Waits until it can write
    try {
        $sync.Counter++ # Acts once it becomes available
    } finally {
        $null = $sync.Semaphore.Release() # Releases so another process can proceed
    }
}
```

If we combine this with the fact that `Parallel` can also be called as a `job`, we get an even more powerful tool. For example, we can create a `job`, receive it later, and display the progress inside a loop:

```PowerShell
$totalItems = 10

$syncTable = [hashtable]::Synchronized(@{
    Semaphore = [System.Threading.SemaphoreSlim]::new(1,1)
    Counter = 0
}) 

$job = 0..10 | ForEach-Object -Parallel {
    $sync = $using:syncTable
    
    Start-Sleep -Seconds 5

    $sync.Semaphore.Wait() 
    try {
        $sync.Counter++ 
    } finally {
        $null = $sync.Semaphore.Release()
    }
} -AsJob

while ($syncTable.Counter -ne $totalItems) {
    Write-Host "Processing: $($syncTable.Counter)/$($totalItems)"
    Start-Sleep 2
}

$completedJob = Receive-Job -Job $job -Wait
Write-Host "Completed..."
```