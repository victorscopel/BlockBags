local _, A = ...

function A:BeginRefreshMeasurement()
    return debugprofilestop and debugprofilestop()
end

function A:FinishRefreshMeasurement(started)
    if not started or not debugprofilestop then return end
    local elapsed=math.max(0,debugprofilestop()-started)
    self.refreshMetrics=self.refreshMetrics or {count=0,total=0,maximum=0}
    local metrics=self.refreshMetrics
    metrics.count=metrics.count+1; metrics.total=metrics.total+elapsed
    metrics.maximum=math.max(metrics.maximum,elapsed); metrics.last=elapsed
end

function A:ReportPerformance()
    local metrics=self.refreshMetrics or {count=0,total=0,maximum=0,last=0}
    self:Print(string.format(self.L["Atualizações: %d; média: %.2f ms; máximo: %.2f ms; última: %.2f ms."],
        metrics.count,metrics.count>0 and metrics.total/metrics.count or 0,metrics.maximum,metrics.last or 0))
    local cache=self:GetOfflineCache()
    local snapshots,items=0,0
    for _,snapshot in pairs(cache.snapshots or {}) do snapshots=snapshots+1; items=items+#snapshot.items end
    self:Print(string.format(self.L["Inventário offline: %d registros; %d itens. Limite: %d itens."],snapshots,items,cache.maxItems or 6000))
    local cpu=C_AddOns and C_AddOns.GetAddOnCPUUsage or GetAddOnCPUUsage
    if cpu and GetCVarBool and GetCVarBool("scriptProfile") then
        self:Print(string.format(self.L["CPU atribuída pelo WoW: %.2f ms."],cpu("BlockBags") or 0))
    end
    self:ReportMemory()
end

function A:ResetPerformanceMeasurements()
    self.refreshMetrics=nil
    self:Print(self.L["Medições de desempenho reiniciadas."])
end
