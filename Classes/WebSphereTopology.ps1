Class WebSphereServer {
    [String] $ServerName
    [String] $ServerConfigDir
    [bool] $IsNodeAgent = $false
    [bool] $IsDmgr = $false

    WebSphereServer () {}

    WebSphereServer ([String] $Name) {
        $this.ServerName = $Name
    }

    [Bool] InitializeFromServerDir([String] $serverDir) {
        [bool] $init = $false
        if (!(Test-Path($serverDir) -PathType Container)) {
            throw [System.IO.DirectoryNotFoundException] "$serverDir directory not found or invalid"
        }

        # Load node info
        [System.IO.FileInfo] $serverXMLFile = Get-ChildItem -Path $serverDir -Filter "server.xml"

        if (!($serverXMLFile) -or (!($serverXMLFile.Exists))) {
            throw [System.IO.FileNotFoundException] "server.xml file not found"
        } else {
            # Set node name
            [XML] $serverXML = Get-Content $serverXMLFile.FullName
            $this.ServerName = ($serverXML.ChildNodes[1] | Select Name).Name
            if ($this.ServerName) {
                $this.ServerConfigDir = $serverDir
                $this.IsNodeAgent = $this.ServerName -eq "nodeagent"
                $this.IsDmgr = $this.ServerName -eq "dmgr"
                $init = $true
            }
        }
        
        Return $init
    }
}

Class WebSphereNode {
    [String] $NodeName
    [WebSphereServer[]] $Servers

    WebSphereNode () {}

    WebSphereNode ([String] $Name) {
        $this.NodeName = $Name
    }

    [void] AddServer([WebSphereServer] $Server) {
        $this.Servers += $Server
    }

    [Bool] InitializeFromNodeDir([String] $nodeDir) {
        [bool] $init = $false
        if (!(Test-Path($nodeDir) -PathType Container)) {
            throw [System.IO.DirectoryNotFoundException] "$nodeDir directory not found or invalid"
        }

        # Load node info
        [System.IO.FileInfo] $nodeXMLFile = Get-ChildItem -Path $nodeDir -Filter "node.xml"

        if (!($nodeXMLFile) -or (!($nodeXMLFile.Exists))) {
            throw [System.IO.FileNotFoundException] "Node.xml file not found"
        } else {
            # Set node name
            [XML] $nodeXML = Get-Content $nodeXMLFile.FullName
            $this.NodeName = ($nodeXML.ChildNodes[1] | Select Name).Name
            if ($this.NodeName) {
                # Load server info
                $serversDir = Join-Path $nodeDir "servers"
                [System.IO.FileInfo[]] $serverXMLFiles = Get-ChildItem -Path $serversDir -Filter "server.xml" -Recurse -Depth 1

                if (!($serverXMLFiles) -or ($serverXMLFiles.Count -le 0)) {
                    Write-Warning "server.xml files not found"
                    $init = $true
                } else {
                    # Adds servers to node
                    foreach ($serverXMLFile in $serverXMLFiles) {
                        [WebSphereServer] $server = [WebSphereServer]::new()
                        $init = $server.InitializeFromServerDir($serverXMLFile.Directory)
                        if ($init) {
                            $this.AddServer($server)
                        }
                    }
                }
            }
        }
        

        Return $init
    }
}

Class WebSphereClusterMember {
    [String] $ServerName
    [String] $NodeName
    [int] $Weight

    WebSphereClusterMember () {}

}

Class WebSphereCluster {
    [String] $ClusterName
    [String] $NodeGroupName
    [String] $ClusterConfigDir
    [WebSphereClusterMember[]] $ClusterMembers

    WebSphereCluster () {}

    WebSphereCluster ([String] $Name) {
        $this.ClusterName = $Name
    }

    [void] AddClusterMember([WebSphereClusterMember] $ClusterMember) {
        $this.ClusterMembers += $ClusterMember
    }

    [Bool] InitializeFromClusterDir([String] $clusterDir) {
        [bool] $init = $false
        if (!(Test-Path($clusterDir) -PathType Container)) {
            throw [System.IO.DirectoryNotFoundException] "$clusterDir directory not found or invalid"
        }

        # Load node info
        [System.IO.FileInfo] $clusterXMLFile = Get-ChildItem -Path $clusterDir -Filter "cluster.xml"

        if (!($clusterXMLFile) -or (!($clusterXMLFile.Exists))) {
            throw [System.IO.FileNotFoundException] "Node.xml file not found"
        } else {
            # Parse cluster info
            [XML] $clusterXML = Get-Content $clusterXMLFile.FullName
            $this.ClusterName = ($clusterXML.ChildNodes[1] | Select Name).Name
            $this.NodeGroupName = ($clusterXML.ChildNodes[1] | Select NodeGroupName).NodeGroupName
            $this.ClusterConfigDir = $clusterDir
            if ($this.ClusterName) {
                $clusterXML.ChildNodes[1].ChildNodes | % {
                    if ($_.Name -eq "Members") {
                        [WebSphereClusterMember] $clusterMember = [WebSphereClusterMember]::new()
                        $clusterMember.ServerName = ($_ | Select memberName).memberName
                        $clusterMember.NodeName = ($_ | Select nodeName).nodeName
                        $clusterMember.Weight = ($_ | Select weight).weight
                        $this.AddClusterMember($clusterMember)
                    }
                }
                $init = $true
            }
        }

        Return $init
    }
}

Class WebSphereCell {
    [String] $CellName
    [WebSphereNode[]] $Nodes
    [WebSphereCluster[]] $Clusters

    WebSphereCell () {}

    WebSphereCell ([String] $Name) {
        $this.CellName = $Name
    }

    [void] AddNode([WebSphereNode] $Node) {
        $this.Nodes += $Node
    }

    [void] AddCluster([WebSphereCluster] $Cluster) {
        $this.Clusters += $Cluster
    }

    [Bool] InitializeFromCellDir([String] $cellDir) {
        [bool] $init = $false
        if (!(Test-Path($cellDir) -PathType Container)) {
            throw [System.IO.DirectoryNotFoundException] "$cellDir directory not found or invalid"
        }

        # Load cell.xml
        [System.IO.FileInfo] $cellXMLFile = Get-ChildItem -Path $cellDir -Filter "cell.xml" -Recurse -Depth 1

        if (!($cellXMLFile) -or (!($cellXMLFile.Exists))) {
            throw [System.IO.FileNotFoundException] "Cell.xml file not found"
        } else {
            # Set cell name
            [XML] $cellXML = Get-Content $cellXMLFile.FullName
            $this.CellName = ($cellXML.ChildNodes[1] | Select Name).Name
            if ($this.CellName) {
                # Load nodes
                $nodesDir = Join-Path $cellDir "nodes"
                [System.IO.FileInfo[]] $nodeXMLFiles = Get-ChildItem -Path $nodesDir -Filter "node.xml" -Recurse -Depth 1

                if (!($nodeXMLFiles) -or ($nodeXMLFiles.Count -le 0)) {
                    Write-Warning "Node.xml files not found"
                    $init = $true
                } else {
                    # Set node name
                    foreach ($nodeXMLFile in $nodeXMLFiles) {
                        [WebSphereNode] $node = [WebSphereNode]::new()
                        $init = $node.InitializeFromNodeDir($nodeXMLFile.Directory)
                        if ($init) {
                            $this.AddNode($node)
                        }
                    }
                }
                # Load clusters
                if ($init) {
                    $clustersDir = Join-Path $cellDir "clusters"
                    [System.IO.FileInfo[]] $clusterXMLFiles = Get-ChildItem -Path $clustersDir -Filter "cluster.xml" -Recurse -Depth 1

                    if (!($clusterXMLFiles) -or ($clusterXMLFiles.Count -le 0)) {
                        Write-Warning "cluster.xml files not found"
                        $init = $true
                    } else {
                        foreach ($clusterXMLFile in $clusterXMLFiles) {
                            [WebSphereCluster] $cluster = [WebSphereCluster]::new()
                            $init = $cluster.InitializeFromClusterDir($clusterXMLFile.Directory)
                            if ($init) {
                                $this.AddCluster($cluster)
                            }
                        }
                    }
                }
            }
        }

        Return $init
    }
}

Class WebSphereTopology {
    [WebSphereCell[]] $Cells

    WebSphereTopology () {}

    [void] AddCell([WebSphereCell] $Cell) {
        $this.Cells += $Cell
    }

    [Bool] InitializeFromProfile([String] $profilePath) {
        [bool] $init = $false
        if (!(Test-Path($profilePath) -PathType Container)) {
            throw [System.IO.DirectoryNotFoundException] "$profilePath directory not found or invalid"
        }

        $cellsDir = Join-Path $profilePath "config\cells"

        if (!(Test-Path($cellsDir) -PathType Container)) {
            throw [System.IO.DirectoryNotFoundException] "Cells directory $cellsDir not found"
        }

        # Load cells.xml
        [System.IO.FileInfo[]] $cellXMLFiles = Get-ChildItem -Path $cellsDir -Filter "cell.xml" -Recurse -Depth 1

        if (!($cellXMLFiles) -or (!($cellXMLFiles.Exists))) {
            throw [System.IO.FileNotFoundException] "Cell.xml file not found"
        } else {
            # Set node name
            foreach ($cellXMLFile in $cellXMLFiles) {
                [WebSphereCell] $cell = [WebSphereCell]::new()
                $init = $cell.InitializeFromCellDir($cellXMLFile.Directory)
                if ($init) {
                    $this.AddCell($cell)
                }
            }
        }

        Return $init
    }
}