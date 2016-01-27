Param ($VIServer=$FALSE, $Cluster=$FALSE)

$SaveFile = [system.Environment]::GetFolderPath('MyDocuments') + "\My_vDrawing.vsd"
if ($VIServer -eq $FALSE) { $VIServer = Read-Host "Please enter a Virtual Center name or ESX Host to diagram:" }

$shpFile = "\My-VI-Shapes.vss"


function connect-visioobject ($firstObj, $secondObj)
{
	$shpConn = $pagObj.Drop($pagObj.Application.ConnectorToolDataObject, 0, 0)

	#// Connect its Begin to the 'From' shape:
	$connectBegin = $shpConn.CellsU("BeginX").GlueTo($firstObj.CellsU("PinX"))
	
	#// Connect its End to the 'To' shape:
	$connectEnd = $shpConn.CellsU("EndX").GlueTo($secondObj.CellsU("PinX"))
}

function add-visioobject ($mastObj, $item)
{
 		Write-Host "Adding $item"
		# Drop the selected stencil on the active page, with the coordinates x, y
  		$shpObj = $pagObj.Drop($mastObj, $x, $y)
		# Enter text for the object
  		$shpObj.Text = $item
		#Return the visioobject to be used
		return $shpObj
 }

# Create an instance of Visio and create a document based on the Basic Diagram template.
$AppVisio = New-Object -ComObject Visio.Application
$docsObj = $AppVisio.Documents
$DocObj = $docsObj.Add("Basic Diagram.vst")

# Set the active page of the document to page 1
$pagsObj = $AppVisio.ActiveDocument.Pages
$pagObj = $pagsObj.Item(1)

# Connect to the VI Server
Write-Host "Connecting to $VIServer"
$VIServer = Connect-VIServer $VIServer

# Load a set of stencils and select one to drop
$stnPath = [system.Environment]::GetFolderPath('MyDocuments') + "\My Shapes"
$stnObj = $AppVisio.Documents.Add($stnPath + $shpFile)
$VCObj = $stnObj.Masters.Item("Virtual Center Management Console")
$HostObj = $stnObj.Masters.Item("ESX Host")
$MSObj = $stnObj.Masters.Item("Microsoft Server")
$LXObj = $stnObj.Masters.Item("Linux Server")
$OtherObj =  $stnObj.Masters.Item("Other Server")
$CluShp = $stnObj.Masters.Item("Cluster")

If ((Get-Cluster) -ne $Null){

	If ($Cluster -eq $FALSE){ 
        $DrawItems = get-cluster 
    }Else {
        $DrawItems = (Get-Cluster $Cluster)
    }
	
	$x = 0
	$VCLocation = $DrawItems | Get-VMHost
	$y = $VCLocation.Length * 1.50 / 2
	
	$VCObject = add-visioobject $VCObj $VIServer
	
	$x = 1.50
	$y = 1.50
	
	ForEach ($Cluster in $DrawItems)
	{
		$CluVisObj = add-visioobject $CluShp $Cluster
		connect-visioobject $VCObject $CluVisObj
		
		$x=3.00
		ForEach ($VMHost in (Get-Cluster $Cluster | Get-VMHost))
		{
			$Object1 = add-visioobject $HostObj $VMHost
			connect-visioobject $CluVisObj $Object1
			ForEach ($VM in (Get-vmhost $VMHost | get-vm))
			{		
				$x += 1.50
				If ($vm.Guest.OSFUllName -eq $Null)
				{
					$Object2 = add-visioobject $OtherObj $VM
				}
				Else
				{
					If ($vm.Guest.OSFUllName.contains("Microsoft") -eq $True)
					{
						$Object2 = add-visioobject $MSObj $VM
					}
					else
					{
						$Object2 = add-visioobject $LXObj $VM
					}
				}	
				connect-visioobject $Object1 $Object2
				$Object1 = $Object2
			}
			$x = 3.00
			$y += 1.50
		}
	$x = 1.50
	}
}
Else
{
	$DrawItems = Get-VMHost
	
	$x = 0
	$y = $DrawItems.Length * 1.50 / 2
	
	$VCObject = add-visioobject $VCObj $VIServer
	
	$x = 1.50
	$y = 1.50
	
	ForEach ($VMHost in $DrawItems)
	{
		$Object1 = add-visioobject $HostObj $VMHost
		connect-visioobject $VCObject $Object1
		ForEach ($VM in (Get-vmhost $VMHost | get-vm))
		{		
			$x += 1.50
			If ($vm.Guest.OSFUllName -eq $Null)
			{
				$Object2 = add-visioobject $OtherObj $VM
			}
			Else
			{
				If ($vm.Guest.OSFUllName.contains("Microsoft") -eq $True)
				{
					$Object2 = add-visioobject $MSObj $VM
				}
				else
				{
					$Object2 = add-visioobject $LXObj $VM
				}
			}	
			connect-visioobject $Object1 $Object2
			$Object1 = $Object2
		}
		$x = 1.50
		$y += 1.50
	}
$x = 1.50
}

# Resize to fit page
$pagObj.ResizeToFitContents()

# Zoom to 50% of the drawing - Not working yet
#$Application.ActiveWindow.Page = $pagObj.NameU
#$AppVisio.ActiveWindow.zoom = [double].5

# Save the diagram
$DocObj.SaveAs("$Savefile")

# Quit Visio
#$AppVisio.Quit()
Write-Output "Document saved as $savefile"
Disconnect-VIServer -Server $VIServer -Confirm:$false